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
using System.Text.Json;

namespace Snarf.Service
{
    public class PartyService(
        UserManager<User> userManager,
        IPartyRepository partyRepository,
        IUserRepository userRepository
    ) : IPartyService
    {
        private const double _randomDistance = 0.045;//5km

        public async Task<ResponseDTO> InviteUsers(Guid id, List<string> userIds)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(x => x.InvitedUsers)
                    .FirstOrDefaultAsync(x => x.Id == id);

                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com o id: {id}");
                    return responseDTO;
                }

                var users = await userRepository
                    .GetTrackedEntities()
                    .Where(u => userIds.Contains(u.Id))
                    .ToListAsync();

                foreach (var user in users)
                {
                    if (!partyEntity.InvitedUsers.Contains(user))
                    {
                        partyEntity.InvitedUsers.Add(user);
                    }
                }

                await partyRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Create(PartyDTO createDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userManager.FindByIdAsync(createDTO.UserId);
                if (user == null)
                {
                    responseDTO.SetBadInput("Não existe o usuário cadastrado com esse email.");
                    return responseDTO;
                }
                var random = new Random();
                var offsetLat = (random.NextDouble() - 0.5) * 2 * _randomDistance;
                var offsetLon = (random.NextDouble() - 0.5) * 2 * _randomDistance;

                var imageBytes = Convert.FromBase64String(createDTO.CoverImage);
                var imageStream = new MemoryStream(imageBytes);
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
                var userEntity = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {userId}!");
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
                    Id = p.Id,
                    Latitude = p.Latitude,
                    Longitude = p.Longitude,
                    Title = p.Title,
                    EventType = p.Type.GetDescription(),
                    ImageUrl = p.CoverImageUrl,
                    UserRole = p.Owner != null && p.Owner.Id == userEntity.Id
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
                var partyEntity = await partyRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id);
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
                await partyRepository.SaveChangesAsync();
                Log.Information("Festa com Id: {id}. Atualizada com sucesso.", partyEntity.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> ConfirmUser(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var targetUserEntity = await userRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (targetUserEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário alvo não encontrado id: {userId}");
                    return responseDTO;
                }

                var whoIsCalling = await userRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (whoIsCalling == null)
                {
                    responseDTO.SetBadInput($"Usuário chamando o método não encontrado id: {userId}");
                    return responseDTO;
                }

                var partyEntity = await partyRepository.GetTrackedEntities()
                    .Include(x => x.InvitedUsers)
                    .Include(x => x.ConfirmedUsers)
                    .FirstOrDefaultAsync(x => x.Id == id);
                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com este id: {id}");
                    return responseDTO;
                }

                bool isHost = (partyEntity.OwnerId == whoIsCalling.Id);

                if (!isHost && whoIsCalling.Id != targetUserEntity.Id)
                {
                    responseDTO.SetBadInput("Você não tem permissão para confirmar outro usuário.");
                    return responseDTO;
                }

                if (partyEntity.InvitedUsers.Contains(targetUserEntity))
                {
                    partyEntity.InvitedUsers.Remove(targetUserEntity);
                    if (!partyEntity.ConfirmedUsers.Contains(targetUserEntity))
                    {
                        partyEntity.ConfirmedUsers.Add(targetUserEntity);
                    }
                    await partyRepository.SaveChangesAsync();
                    Log.Information("Confirmado presença para user: {0} na festa {1}", targetUserEntity.Id, partyEntity.Id);
                }
                else
                {
                    responseDTO.SetBadInput("Usuário não está na lista de convidados para ser confirmado.");
                }
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> DeclineUser(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var targetUserEntity = await userRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (targetUserEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário alvo não encontrado id: {userId}");
                    return responseDTO;
                }

                var whoIsCalling = await userRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (whoIsCalling == null)
                {
                    responseDTO.SetBadInput($"Usuário chamando o método não encontrado id: {userId}");
                    return responseDTO;
                }

                var partyEntity = await partyRepository.GetTrackedEntities()
                    .Include(x => x.InvitedUsers)
                    .Include(x => x.ConfirmedUsers)
                    .FirstOrDefaultAsync(x => x.Id == id);
                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com este id: {id}");
                    return responseDTO;
                }

                bool isHost = (partyEntity.OwnerId == whoIsCalling.Id);

                if (!isHost && whoIsCalling.Id != targetUserEntity.Id)
                {
                    responseDTO.SetBadInput("Você não tem permissão para recusar outro usuário.");
                    return responseDTO;
                }

                if (partyEntity.InvitedUsers.Contains(targetUserEntity))
                {
                    partyEntity.InvitedUsers.Remove(targetUserEntity);
                }

                if (partyEntity.ConfirmedUsers.Contains(targetUserEntity))
                {
                    partyEntity.ConfirmedUsers.Remove(targetUserEntity);
                }

                await partyRepository.SaveChangesAsync();
                Log.Information("Usuário {0} removido/recusado da festa {1}", targetUserEntity.Id, partyEntity.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetAllParticipants(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {userId}!");
                    return responseDTO;
                }
                var partyEntity = await partyRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id);
                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com este id: {id}");
                    return responseDTO;
                }
                var inviteds = partyEntity.InvitedUsers.Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.ImageUrl
                });
                var confirmeds = partyEntity.ConfirmedUsers.Select(x => new
                {
                    x.Id,
                    x.Name,
                    x.ImageUrl
                });
                var data = new
                {
                    Id = id,
                    EventType = partyEntity.Type.GetDescription(),
                    ImagemUrl = partyEntity.CoverImageUrl,
                    Title = partyEntity.Title,
                    Location = partyEntity.Location,
                    Owner = partyEntity.Owner,
                    Inviteds = inviteds,
                    Confirmeds = confirmeds,
                    isOwner = partyEntity.Owner.Id == userId.ToString()
                };
                var a = JsonSerializer.Serialize(data);
                Log.Information(a);
                responseDTO.Object = data;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetById(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {userId}!");
                    return responseDTO;
                }
                var partyEntity = await partyRepository
                    .GetTrackedEntities()
                    .Include(p => p.Owner)
                    .Include(p => p.InvitedUsers)
                    .Include(p => p.ConfirmedUsers)
                    .FirstOrDefaultAsync(p => p.Id == id);
                if (partyEntity == null)
                {
                    responseDTO.SetBadInput($"Festa não encontrada com este id: {id}");
                    return responseDTO;
                }
                var userRole = "Disponível para Participar";
                if (partyEntity.InvitedUsers.Contains(userEntity))
                    userRole = "Convidado";
                else if (partyEntity.ConfirmedUsers.Contains(userEntity))
                    userRole = "Confirmado";
                else if (partyEntity.OwnerId == userEntity.Id)
                    userRole = "Hospedando";
                var data = new
                {
                    Id = partyEntity.Id,
                    Title = partyEntity.Title,
                    Description = partyEntity.Description,
                    StartDate = partyEntity.StartDate,
                    Duration = partyEntity.Duration,
                    Type = partyEntity.Type,
                    Location = partyEntity.Location,
                    Instructions = partyEntity.Instructions,
                    Latitude = partyEntity.Latitude,
                    Longitude = partyEntity.Longitude,
                    CoverImageUrl = partyEntity.CoverImageUrl,
                    OwnerId = partyEntity.OwnerId,
                    OwnerName = partyEntity.Owner.Name,
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

        public async Task<ResponseDTO> Delete(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var partyEntity = await partyRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id);
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

        public Task<ResponseDTO> Remove(Guid id)
        {
            throw new NotImplementedException();
        }

        public Task<ResponseDTO> GetList()
        {
            throw new NotImplementedException();
        }
    }
}