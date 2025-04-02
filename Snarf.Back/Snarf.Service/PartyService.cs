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
        public async Task<ResponseDTO> InviteUsers(Guid id, AddUsersToPartyDTO request)
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

                var users = await userRepository.
                    GetTrackedEntities()
                    .Where(x => request.UserIds.Contains(x.Id))
                    .ToListAsync();

                foreach (var user in users)
                {
                    if (!partyEntity.InvitedUsers.Contains(user))
                    {
                        partyEntity.InvitedUsers.Add(user);
                    }
                }

                await partyRepository.SaveChangesAsync();
                responseDTO.Object = partyEntity;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> Create(PartyCreateDTO createDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userManager.FindByEmailAsync(createDTO.Email);
                if (user == null)
                {
                    responseDTO.SetBadInput($"Não existe o usuário cadastrado com esse email.");
                    return responseDTO;
                }

                var imageBytes = Convert.FromBase64String(createDTO.CoverImage);
                var imageStream = new MemoryStream(imageBytes);
                var s3Service = new S3Service();
                var imageUrl = await s3Service.UploadFileAsync($"partyImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

                var partyEntity = new Party
                {
                    Title = createDTO.Title,
                    Description = createDTO.Description,
                    StartDate = createDTO.StartDate,
                    Duration = createDTO.Duration,
                    Type = createDTO.Type,
                    Location = createDTO.Location,
                    Instructions = createDTO.Instructions,
                    Latitude = createDTO.LastLatitude,
                    Longitude = createDTO.LastLongitude,
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
                    .ToListAsync();

                var data = new List<PartiesResponseDTO>();

                foreach (var party in parties)
                {
                    var newParty = new PartiesResponseDTO
                    {
                        Id = party.Id,
                        Latitude = party.Latitude,
                        Longitude = party.Longitude,
                        Title = party.Title,
                        EventType = party.Type.GetDescription(),
                        ImageUrl = party.CoverImageUrl
                    };

                    if (party.InvitedUsers.Contains(userEntity))
                        newParty.UserRole = "Convidado";
                    else if (party.ConfirmedUsers.Contains(userEntity))
                        newParty.UserRole = "Confirmado";
                    else if (party.Owner.Id == userEntity.Id)
                        newParty.UserRole = "Hospedando";
                    else
                        newParty.UserRole = "Disponível para Participar";

                    data.Add(newParty);
                }

                responseDTO.Object = data;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> Update(Guid id, PartyUpdateDTO updateDTO)
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

                if (partyEntity.InvitedUsers.Contains(userEntity))
                {
                    partyEntity.ConfirmedUsers.Add(userEntity);
                    partyEntity.InvitedUsers.Remove(userEntity);
                }

                await partyRepository.SaveChangesAsync();
                Log.Information("Confirmado presença para id: {id}", userEntity.Id);
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
    }
}
