using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;
using Snarf.Utils;

namespace Snarf.Service
{
    public class PartyService(
        UserManager<User> userManager,
        IPartyRepository partyRepository,
        IUserRepository userRepository
    ) : IPartyService
    {
        // A distância para gerar latitude e longitude aleatória (você que definiu)
        private const double _randomDistance = 0.045; // 5km (aprox)

        public async Task<ResponseDTO> Create(PartyDTO createDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userManager.FindByIdAsync(createDTO.UserId);
                if (user == null)
                {
                    responseDTO.SetBadInput("Não existe usuário com esse Id.");
                    return responseDTO;
                }

                // Gera deslocamento aleatório (seu critério) para "esconder" a localização
                var random = new Random();
                var offsetLat = (random.NextDouble() - 0.5) * 2 * _randomDistance;
                var offsetLon = (random.NextDouble() - 0.5) * 2 * _randomDistance;

                // Faz upload da imagem da capa (coverImage) para o S3
                var imageBytes = Convert.FromBase64String(createDTO.CoverImage);
                using var imageStream = new MemoryStream(imageBytes);
                var s3Service = new S3Service();
                var imageUrl = await s3Service.UploadFileAsync(
                    $"partyImages/{Guid.NewGuid()}{Guid.NewGuid()}",
                    imageStream,
                    "image/jpeg"
                );

                // Cria a festa
                var partyEntity = new Party
                {
                    Title = createDTO.Title,
                    Description = createDTO.Description,
                    StartDate = createDTO.StartDate,
                    Duration = createDTO.Duration,
                    Type = createDTO.Type,
                    Location = createDTO.Location,
                    Instructions = createDTO.Instructions,
                    Latitude = createDTO.LastLatitude + offsetLat,
                    Longitude = createDTO.LastLongitude + offsetLon,
                    CoverImageUrl = imageUrl,
                    OwnerId = user.Id,
                    Owner = user
                };
                await partyRepository.InsertAsync(partyEntity);
                await partyRepository.SaveChangesAsync();

                Log.Information("Festa persistida com sucesso. Id: {id}", partyEntity.Id);

                responseDTO.Object = createDTO;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetAll(Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userId.ToString());

                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com id: {userId}!");
                    return responseDTO;
                }

                // Retorna todas as festas que ainda não expiraram
                var parties = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.Owner)
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .Where(p => p.StartDate.AddHours(p.Duration) >= DateTime.Now)
                    .ToListAsync();

                // Mapeia para um objeto anônimo e define a “userRole”
                var data = parties.Select(p => new
                {
                    p.Id,
                    p.Latitude,
                    p.Longitude,
                    p.Title,
                    EventType = p.Type.GetDescription(),
                    ImageUrl = p.CoverImageUrl,
                    UserRole = (p.Owner != null && p.Owner.Id == userEntity.Id)
                        ? "Hospedando"
                        : p.InvitedUsers.Any(u => u.Id == userEntity.Id)
                            ? "Convidado"
                            : p.ConfirmedUsers.Any(u => u.Id == userEntity.Id)
                                ? "Confirmado"
                                : "Disponível para Participar"
                })
                .ToList();

                responseDTO.Object = data;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Update(Guid id, PartyDTO updateDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == id);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com o id: {id}");
                    return responseDTO;
                }

                // Atualiza os campos editáveis
                partyEntity.Title = updateDTO.Title;
                partyEntity.Description = updateDTO.Description;
                partyEntity.Location = updateDTO.Location;
                partyEntity.Instructions = updateDTO.Instructions;
                partyEntity.StartDate = updateDTO.StartDate;
                partyEntity.Duration = updateDTO.Duration;

                await partyRepository.SaveChangesAsync();
                Log.Information("Festa com Id: {id} atualizada com sucesso.", partyEntity.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Delete(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var partyEntity = await partyRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == id);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com este id: {id}");
                    return responseDTO;
                }

                if (partyEntity.OwnerId != userId.ToString())
                {
                    responseDTO.SetBadInput("Apenas o dono da festa pode excluir.");
                    return responseDTO;
                }

                partyRepository.Delete(partyEntity);
                await partyRepository.SaveChangesAsync();

                Log.Information("Festa excluída com id: {id}", id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // 1) Host convida explicitamente
        public async Task<ResponseDTO> InviteUsers(Guid id, List<string> userIds, string whoIsCallingId)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(x => x.Id == id);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                // Verifica se quem chama é o host
                //if (partyEntity.OwnerId != whoIsCallingId)
                //{
                //    responseDTO.SetBadInput("Apenas o anfitrião pode convidar.");
                //    return responseDTO;
                //}

                var usersToInvite = await userRepository
                    .GetTrackedEntities()
                    .Where(u => userIds.Contains(u.Id))
                    .ToListAsync();

                foreach (var user in usersToInvite)
                {
                    // se já estiver confirmado ou convidado, não precisa
                    if (partyEntity.ConfirmedUsers.Contains(user) ||
                        partyEntity.InvitedUsers.Contains(user))
                        continue;

                    // adiciona na lista de convidados
                    partyEntity.InvitedUsers.Add(user);

                    // marca no dicionário que foi convidado pelo host
                    partyEntity.InvitedByHostMap[user.Id] = true;
                }

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // 2) Usuário solicita participação (auto-solicitação)
        public async Task<ResponseDTO> RequestParticipation(Guid partyId, string userId)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(x => x.Id == partyId);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                // se já está convidado ou confirmado, não faz nada
                if (partyEntity.InvitedUsers.Any(u => u.Id == userId) ||
                    partyEntity.ConfirmedUsers.Any(u => u.Id == userId))
                {
                    responseDTO.SetBadInput("Você já está na lista da festa.");
                    return responseDTO;
                }

                var user = await userRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(u => u.Id == userId);

                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado.");
                    return responseDTO;
                }

                // Adiciona na lista de convidados como "solicitação"
                partyEntity.InvitedUsers.Add(user);

                // marca que NÃO foi convidado pelo host
                partyEntity.InvitedByHostMap[user.Id] = false;

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // Confirmar (aceitar)
        public async Task<ResponseDTO> ConfirmUser(Guid partyId, string whoIsCallingId, string targetUserId)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(p => p.Id == partyId);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                var targetUser = await userRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(u => u.Id == targetUserId);

                if (targetUser == null)
                {
                    responseDTO.SetBadInput("Usuário alvo não encontrado.");
                    return responseDTO;
                }

                // Verifica se o user alvo está mesmo em Invited
                if (!partyEntity.InvitedUsers.Contains(targetUser))
                {
                    responseDTO.SetBadInput("O usuário não está na lista de convidados pendentes.");
                    return responseDTO;
                }

                // Descobre se foi convidado pelo host
                bool wasInvitedByHost = false;
                if (partyEntity.InvitedByHostMap.ContainsKey(targetUserId))
                {
                    wasInvitedByHost = partyEntity.InvitedByHostMap[targetUserId];
                }

                bool isHost = (partyEntity.OwnerId == whoIsCallingId);
                bool isSameUser = (targetUserId == whoIsCallingId);

                // Regras:
                // - Se foi convidado pelo host (wasInvitedByHost=true), então o próprio user pode se confirmar
                //   OU o host pode confirmar ele.
                // - Se foi "solicitação" (wasInvitedByHost=false), só o host pode confirmar.
                if (wasInvitedByHost)
                {
                    // Convidado => user pode se confirmar, ou o host confirma
                    if (!isHost && !isSameUser)
                    {
                        responseDTO.SetBadInput("Apenas o convidado ou o anfitrião podem confirmar.");
                        return responseDTO;
                    }
                }
                else
                {
                    // Solicitante => apenas o anfitrião pode confirmar
                    if (!isHost)
                    {
                        responseDTO.SetBadInput("Apenas o anfitrião pode aceitar uma solicitação de participação.");
                        return responseDTO;
                    }
                }

                // -> tudo ok, remove de Invited e põe em Confirmed
                partyEntity.InvitedUsers.Remove(targetUser);
                if (!partyEntity.ConfirmedUsers.Contains(targetUser))
                {
                    partyEntity.ConfirmedUsers.Add(targetUser);
                }

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // Recusar (declinar)
        public async Task<ResponseDTO> DeclineUser(Guid partyId, string whoIsCallingId, string targetUserId)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(p => p.Id == partyId);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                var targetUser = await userRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(u => u.Id == targetUserId);

                if (targetUser == null)
                {
                    responseDTO.SetBadInput("Usuário alvo não encontrado.");
                    return responseDTO;
                }

                // Se não está nem convidado nem confirmado, não faz sentido
                bool isInvited = partyEntity.InvitedUsers.Contains(targetUser);
                bool isConfirmed = partyEntity.ConfirmedUsers.Contains(targetUser);
                if (!isInvited && !isConfirmed)
                {
                    responseDTO.SetBadInput("O usuário não está nessa festa.");
                    return responseDTO;
                }

                // Regras de permissão de recusa:
                // - O próprio usuário pode se recusar (caso tenha sido convidado ou solicitou)
                // - O anfitrião pode recusar qualquer um
                bool isHost = (partyEntity.OwnerId == whoIsCallingId);
                bool isSameUser = (targetUserId == whoIsCallingId);
                if (!isHost && !isSameUser)
                {
                    responseDTO.SetBadInput("Você não pode recusar outro usuário.");
                    return responseDTO;
                }

                // Remove de Invited/Confirmed
                if (isInvited)
                {
                    partyEntity.InvitedUsers.Remove(targetUser);
                }
                if (isConfirmed)
                {
                    partyEntity.ConfirmedUsers.Remove(targetUser);
                }

                // Se quiser, remove do dictionary InvitedByHostMap também
                if (partyEntity.InvitedByHostMap.ContainsKey(targetUserId))
                {
                    partyEntity.InvitedByHostMap.Remove(targetUserId);
                }

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // Exibir detalhes e atribuir userRole
        public async Task<ResponseDTO> GetById(Guid id, Guid userId)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.Owner)
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                var userRole = "Disponível para Participar";
                if (partyEntity.OwnerId == userId.ToString())
                {
                    userRole = "Hospedando";
                }
                else if (partyEntity.ConfirmedUsers.Any(u => u.Id == userId.ToString()))
                {
                    userRole = "Confirmado";
                }
                else if (partyEntity.InvitedUsers.Any(u => u.Id == userId.ToString()))
                {
                    // Se estiver em InvitedUsers, checa se InvitedByHostMap = true/false
                    bool wasInvitedByHost = false;
                    if (partyEntity.InvitedByHostMap.TryGetValue(userId.ToString(), out var flag))
                    {
                        wasInvitedByHost = flag;
                    }
                    userRole = wasInvitedByHost ? "Convidado" : "Solicitante";
                }

                var data = new
                {
                    Id = partyEntity.Id,
                    partyEntity.Title,
                    partyEntity.Description,
                    partyEntity.StartDate,
                    partyEntity.Duration,
                    partyEntity.Type,
                    partyEntity.Location,
                    partyEntity.Instructions,
                    partyEntity.CoverImageUrl,
                    OwnerId = partyEntity.OwnerId,
                    InvitedCount = partyEntity.InvitedUsers.Count,
                    ConfirmedCount = partyEntity.ConfirmedUsers.Count,
                    UserRole = userRole
                };

                responseDTO.Object = data;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // Para exibir a lista de pendentes (Invited) e confirmados (Confirmed)
        // de modo que todos vejam os confirmados e só o host veja os pendentes
        public async Task<ResponseDTO> GetAllParticipants(Guid partyId, Guid whoIsCalling)
        {
            var responseDTO = new ResponseDTO();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(p => p.Id == partyId);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput("Festa não encontrada.");
                    return responseDTO;
                }

                // Pega confirmados (sempre exibimos)
                var confirmeds = partyEntity.ConfirmedUsers.Select(u => new
                {
                    u.Id,
                    u.Name,
                    u.ImageUrl
                }).ToList();

                // Pega pendentes (Invited)
                // Se o chamador for o dono, exibe todos.
                // Se não for o dono, a critério seu exibir apenas "Convidado" ou "Solicitante" do próprio user etc.
                var inviteds = new List<object>();
                bool isHost = (partyEntity.OwnerId == whoIsCalling.ToString());
                if (isHost)
                {
                    inviteds = partyEntity.InvitedUsers.Select(u => new
                    {
                        u.Id,
                        u.Name,
                        u.ImageUrl
                    }).ToList<object>();
                }

                responseDTO.Object = new
                {
                    Inviteds = inviteds,
                    Confirmeds = confirmeds
                };
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        // Métodos não implementados...
        public Task<ResponseDTO> Remove(Guid id) => throw new NotImplementedException();
        public Task<ResponseDTO> GetList() => throw new NotImplementedException();
    }
}