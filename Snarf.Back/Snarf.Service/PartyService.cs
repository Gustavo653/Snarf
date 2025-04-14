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

                var random = new Random();
                var offsetLat = (random.NextDouble() - 0.5) * 2 * _randomDistance;
                var offsetLon = (random.NextDouble() - 0.5) * 2 * _randomDistance;

                var imageBytes = Convert.FromBase64String(createDTO.CoverImage);
                using var imageStream = new MemoryStream(imageBytes);
                var s3Service = new S3Service();
                var imageUrl = await s3Service.UploadFileAsync(
                    $"partyImages/{Guid.NewGuid()}{Guid.NewGuid()}",
                    imageStream,
                    "image/jpeg"
                );

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

                var parties = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.Owner)
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .Where(p => p.StartDate.AddHours(p.Duration) >= DateTime.Now)
                    .ToListAsync();

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

                partyEntity.Title = updateDTO.Title;
                partyEntity.Description = updateDTO.Description;
                partyEntity.Location = updateDTO.Location;
                partyEntity.Instructions = updateDTO.Instructions;
                partyEntity.StartDate = updateDTO.StartDate;
                partyEntity.Duration = updateDTO.Duration;

                if (!string.IsNullOrWhiteSpace(updateDTO.CoverImage))
                {
                    var s3Service = new S3Service();
                    if (!string.IsNullOrWhiteSpace(partyEntity.CoverImageUrl) && partyEntity.CoverImageUrl.StartsWith("https://"))
                    {
                        await s3Service.DeleteFileAsync(partyEntity.CoverImageUrl);
                    }
                    var imageBytes = Convert.FromBase64String(updateDTO.CoverImage);
                    using var imageStream = new MemoryStream(imageBytes);
                    var newCoverUrl = await s3Service.UploadFileAsync($"placeImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");
                    partyEntity.CoverImageUrl = newCoverUrl;
                }

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
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(x => x.Messages)
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

                var urls = partyEntity.Messages.Where(x => x.Message.StartsWith("https://")).Select(x => x.Message).ToList();
                urls.Add(partyEntity.CoverImageUrl);

                foreach (var url in urls)
                {
                    try
                    {
                        var s3Service = new S3Service();
                        await s3Service.DeleteFileAsync(url);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(ex, $"Erro ao deletar arquivo S3: {url}");
                    }
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

                var usersToInvite = await userRepository
                    .GetTrackedEntities()
                    .Where(u => userIds.Contains(u.Id))
                    .ToListAsync();

                foreach (var user in usersToInvite)
                {
                    if (partyEntity.ConfirmedUsers.Contains(user) ||
                        partyEntity.InvitedUsers.Contains(user))
                        continue;

                    partyEntity.InvitedUsers.Add(user);

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

                partyEntity.InvitedUsers.Add(user);

                partyEntity.InvitedByHostMap[user.Id] = false;

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

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

                if (!partyEntity.InvitedUsers.Contains(targetUser))
                {
                    responseDTO.SetBadInput("O usuário não está na lista de convidados pendentes.");
                    return responseDTO;
                }

                bool wasInvitedByHost = false;
                if (partyEntity.InvitedByHostMap.ContainsKey(targetUserId))
                {
                    wasInvitedByHost = partyEntity.InvitedByHostMap[targetUserId];
                }

                bool isHost = (partyEntity.OwnerId == whoIsCallingId);
                bool isSameUser = (targetUserId == whoIsCallingId);

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
                    if (!isHost)
                    {
                        responseDTO.SetBadInput("Apenas o anfitrião pode aceitar uma solicitação de participação.");
                        return responseDTO;
                    }
                }

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

                bool isInvited = partyEntity.InvitedUsers.Contains(targetUser);
                bool isConfirmed = partyEntity.ConfirmedUsers.Contains(targetUser);
                if (!isInvited && !isConfirmed)
                {
                    responseDTO.SetBadInput("O usuário não está nessa festa.");
                    return responseDTO;
                }

                bool isHost = (partyEntity.OwnerId == whoIsCallingId);
                bool isSameUser = (targetUserId == whoIsCallingId);
                if (!isHost && !isSameUser)
                {
                    responseDTO.SetBadInput("Você não pode recusar outro usuário.");
                    return responseDTO;
                }

                if (isInvited)
                {
                    partyEntity.InvitedUsers.Remove(targetUser);
                }
                if (isConfirmed)
                {
                    partyEntity.ConfirmedUsers.Remove(targetUser);
                }

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

                var confirmeds = partyEntity.ConfirmedUsers.Select(u => new
                {
                    u.Id,
                    u.Name,
                    u.ImageUrl
                }).ToList();

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

        public Task<ResponseDTO> Remove(Guid id) => throw new NotImplementedException();
        public Task<ResponseDTO> GetList() => throw new NotImplementedException();
    }
}