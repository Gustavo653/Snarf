using FloralImage.Domain.Location;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using Serilog;

namespace FloralImage.Service
{
    public class StateService(IStateRepository stateRepository, ICityService cityService) : IStateService
    {
        public async Task<ResponseDTO> GetStates()
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await stateRepository
                    .GetEntities()
                    .Select(x => new
                    {
                        x.Id,
                        x.Code,
                        x.Name,
                        CitiesCount = x.Cities.Count,
                        x.CreatedAt,
                        x.UpdatedAt
                    })
                    .OrderBy(x => x.Name)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public Task<ResponseDTO> SyncStates()
        {
            ResponseDTO responseDTO = new();
            try
            {
                Hangfire.BackgroundJob.Enqueue(() => CreateOrUpdateStates());
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return Task.FromResult(responseDTO);
        }

        public async Task CreateOrUpdateStates()
        {
            Log.Information("Buscando estados da API");
            var apiStates = await GetAPIStates();
            Log.Information($"Foram encontrados {apiStates.Count} estados na API");

            Log.Information("Buscando estados do banco");
            var repositoryStates = await stateRepository.GetEntities().ToListAsync();
            Log.Information($"Foram encontrados {repositoryStates.Count} estados no banco");
            var repositoryStatesDict = repositoryStates.ToDictionary(b => b.Code);

            Log.Information("Validando os estados");
            foreach (var apiState in apiStates)
            {
                if (repositoryStatesDict.TryGetValue(apiState.Id, out var repositoryState))
                {
                    if (repositoryState.Name != apiState.Nome || repositoryState.Abbreviation != apiState.Sigla)
                    {
                        Log.Warning($"Atualizando o estado {repositoryState.Code} de {repositoryState.Name} para {apiState.Nome}");
                        repositoryState.Name = apiState.Nome;
                        repositoryState.Abbreviation = apiState.Sigla;
                        stateRepository.Update(repositoryState);
                    }
                }
                else
                {
                    Log.Warning($"Criando o estado {apiState.Nome}");
                    await stateRepository.InsertAsync(new State() { Name = apiState.Nome, Code = apiState.Id, Abbreviation = apiState.Sigla });
                }
            }

            await stateRepository.SaveChangesAsync();

            Hangfire.BackgroundJob.Enqueue(() => cityService.SyncCities());
        }

        private async Task<List<StateDTO>> GetAPIStates()
        {
            using HttpClient client = new();
            const string url = $"{Consts.UrlBaseIBGE}/estados";
            string response = await client.GetStringAsync(url);

            var states = JsonConvert.DeserializeObject<List<StateDTO>>(response) ??
                         throw new NullReferenceException($"Não foi encontrada nenhuma marca");

            return states;
        }

        private record StateDTO
        {
            public int Id { get; set; }
            public string Sigla { get; set; }
            public string Nome { get; set; }
        }
    }
}