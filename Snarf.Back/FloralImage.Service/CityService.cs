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
    public class CityService(IStateRepository stateRepository, ICityRepository cityRepository) : ICityService
    {
        public async Task<ResponseDTO> GetCitiesByState(Guid stateId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await cityRepository
                    .GetEntities()
                    .Where(x => x.State.Id == stateId)
                    .Select(x => new
                    {
                        x.Id,
                        x.Code,
                        x.Name,
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

        public Task<ResponseDTO> SyncCities()
        {
            ResponseDTO responseDTO = new();
            try
            {
                Hangfire.BackgroundJob.Enqueue(() => CreateOrUpdateCities());
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return Task.FromResult(responseDTO);
        }

        public async Task CreateOrUpdateCities()
        {
            Log.Information("Buscando estados do banco");
            var states = await stateRepository.GetTrackedEntities().ToListAsync();
            foreach (var state in states)
            {
                var apiCities = await GetAPICities(state.Code);
                Log.Information($"Foram encontrados {apiCities.Count} cidades na API");

                Log.Information($"Buscando cidades do banco para o estado {state.Name}");
                var repositoryCities = await cityRepository.GetEntities().Where(x => x.State == state).ToListAsync();
                Log.Information($"Foram encontradas {repositoryCities.Count} cidades no banco para a marca {state.Name}");
                var repositoryCitiesDict = repositoryCities.ToDictionary(b => b.Code);

                Log.Information("Validando as cidades");
                foreach (var apiCity in apiCities)
                {
                    if (repositoryCitiesDict.TryGetValue(apiCity.Id, out var repositoryCity))
                    {
                        if (repositoryCity.Name != apiCity.Nome)
                        {
                            Log.Warning($"Atualizando a cidade {repositoryCity.Code} de {repositoryCity.Name} para {apiCity.Nome}");
                            repositoryCity.Name = apiCity.Nome;
                            cityRepository.Update(repositoryCity);
                        }
                    }
                    else
                    {
                        Log.Warning($"Criando a cidade {apiCity.Nome}");
                        await cityRepository.InsertAsync(new City() { Name = apiCity.Nome, Code = apiCity.Id, State = state });
                    }
                }
                await cityRepository.SaveChangesAsync();
            }
        }

        private async Task<List<CityDTO>> GetAPICities(int id)
        {
            using HttpClient client = new();
            var url = $"{Consts.UrlBaseIBGE}/estados/{id}/municipios";
            string response = await client.GetStringAsync(url);

            var cities = JsonConvert.DeserializeObject<List<CityDTO>>(response) ??
                         throw new NullReferenceException("Não foi encontrada nenhuma marca");

            return cities;
        }

        private class CityDTO
        {
            public int Id { get; set; }
            public string Nome { get; set; }
        }
    }
}
