using Hangfire;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;

namespace Snarf.Service
{
    public class PlaceService(
        UserManager<User> userManager,
        IPlaceRepository placeRepository,
        IPlaceVisitLogRepository placeVisitLogRepository,
        IEmailService emailService
    ) : IPlaceService
    {
        public async Task<ResponseDTO> Create(PlaceDTO createDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userManager.FindByIdAsync(createDTO.UserId);
                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado.");
                    return responseDTO;
                }

                var imageUrl = "";
                if (!string.IsNullOrWhiteSpace(createDTO.CoverImage))
                {
                    var imageBytes = Convert.FromBase64String(createDTO.CoverImage);
                    using var imageStream = new MemoryStream(imageBytes);
                    var s3Service = new S3Service();
                    imageUrl = await s3Service.UploadFileAsync($"placeImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");
                }

                var placeEntity = new Place
                {
                    Title = createDTO.Title,
                    Description = createDTO.Description,
                    Latitude = createDTO.Latitude,
                    Longitude = createDTO.Longitude,
                    OwnerId = user.Id,
                    CoverImageUrl = imageUrl,
                    Type = createDTO.Type
                };

                await placeRepository.InsertAsync(placeEntity);
                await placeRepository.SaveChangesAsync();
                responseDTO.Object = createDTO;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> Update(Guid id, PlaceDTO updateDTO, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var placeEntity = await placeRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == id);
                if (placeEntity == null)
                {
                    responseDTO.SetBadInput($"Lugar não encontrado com o id: {id}");
                    return responseDTO;
                }
                if (placeEntity.OwnerId != userId.ToString())
                {
                    responseDTO.SetBadInput("Apenas o dono do lugar pode editar.");
                    return responseDTO;
                }
                placeEntity.Title = updateDTO.Title;
                placeEntity.Description = updateDTO.Description;
                placeEntity.Latitude = updateDTO.Latitude;
                placeEntity.Longitude = updateDTO.Longitude;
                placeEntity.Type = updateDTO.Type;

                if (!string.IsNullOrWhiteSpace(updateDTO.CoverImage))
                {
                    var s3Service = new S3Service();
                    if (!string.IsNullOrWhiteSpace(placeEntity.CoverImageUrl) && placeEntity.CoverImageUrl.StartsWith("https://"))
                    {
                        await s3Service.DeleteFileAsync(placeEntity.CoverImageUrl);
                    }
                    var imageBytes = Convert.FromBase64String(updateDTO.CoverImage);
                    using var imageStream = new MemoryStream(imageBytes);
                    var newCoverUrl = await s3Service.UploadFileAsync($"placeImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");
                    placeEntity.CoverImageUrl = newCoverUrl;
                }

                await placeRepository.SaveChangesAsync();
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
                var placeEntity = await placeRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == id);
                if (placeEntity == null)
                {
                    responseDTO.SetBadInput($"Lugar não encontrado com este id: {id}");
                    return responseDTO;
                }
                if (placeEntity.OwnerId != userId.ToString())
                {
                    responseDTO.SetBadInput("Apenas o dono do lugar pode excluir.");
                    return responseDTO;
                }

                try
                {
                    var s3Service = new S3Service();
                    await s3Service.DeleteFileAsync(placeEntity.CoverImageUrl);
                }
                catch (Exception ex)
                {
                    Log.Error(ex, $"Erro ao excluir a imagem do S3. {placeEntity.CoverImageUrl}");
                }

                placeRepository.Delete(placeEntity);
                await placeRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetById(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var placeEntity = await placeRepository
                    .GetTrackedEntities()
                    .Include(x => x.Owner)
                    .FirstOrDefaultAsync(x => x.Id == id);
                if (placeEntity == null)
                {
                    responseDTO.SetBadInput("Lugar não encontrado.");
                    return responseDTO;
                }
                responseDTO.Object = new
                {
                    placeEntity.Id,
                    placeEntity.Title,
                    placeEntity.Description,
                    placeEntity.Latitude,
                    placeEntity.Longitude,
                    placeEntity.Type,
                    placeEntity.OwnerId,
                    placeEntity.CoverImageUrl
                };
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetAll()
        {
            ResponseDTO responseDTO = new();
            try
            {
                var places = await placeRepository
                    .GetTrackedEntities()
                    .Select(x => new
                    {
                        x.Id,
                        x.Title,
                        x.Description,
                        x.Latitude,
                        x.Longitude,
                        x.OwnerId
                    })
                    .ToListAsync();
                responseDTO.Object = places;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> SignalToRemove(Guid id, Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var placeEntity = await placeRepository
                    .GetTrackedEntities()
                    .Include(p => p.Owner)
                    .FirstOrDefaultAsync(p => p.Id == id);

                if (placeEntity == null)
                {
                    responseDTO.SetBadInput($"Lugar não encontrado com este id: {id}");
                    return responseDTO;
                }

                var subject = "Solicitação de Remoção de Local - Snarf";
                var body = emailService.BuildRemovePlaceText(
                    placeEntity.Title,
                    placeEntity.Id,
                    placeEntity.Owner?.Name ?? "Usuário desconhecido",
                    placeEntity.Owner?.Email ?? "Email desconhecido"
                );

                BackgroundJob.Enqueue(() => emailService.SendEmail(
                    subject,
                    body,
                    "oficial.snarf@gmail.com"
                ));

                responseDTO.Message = "Solicitação de remoção enviada com sucesso!";
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetVisitorsAndStats(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var place = await placeRepository.GetEntities().FirstOrDefaultAsync(p => p.Id == id);

                if (place == null)
                {
                    responseDTO.SetBadInput($"Lugar não encontrado com este id: {id}.");
                    return responseDTO;
                }

                var sevenDaysAgo = DateTime.Now.AddDays(-7);
                var visitLogs = await placeVisitLogRepository.GetEntities()
                    .Include(x => x.User)
                    .Where(v => v.PlaceId == place.Id)
                    .ToListAsync();

                var currentVisitors = visitLogs
                    .Where(v => v.ExitTime == null)
                    .Select(v => v.User)
                    .Distinct()
                    .Select(u => new
                    {
                        id = u.Id,
                        name = u.Name,
                        imageUrl = u.GetFirstPhoto
                    })
                    .ToList();

                var recentVisits = visitLogs
                    .Where(v => v.ExitTime != null && v.ExitTime >= sevenDaysAgo)
                    .ToList();

                var visitsLast7Days = recentVisits.Count;
                double averageStayMinutes = 0;
                if (recentVisits.Any(v => v.TotalDurationInMinutes.HasValue))
                {
                    averageStayMinutes = recentVisits
                        .Where(v => v.TotalDurationInMinutes.HasValue)
                        .Average(v => v.TotalDurationInMinutes.Value);
                }

                responseDTO.Object = new
                {
                    currentVisitors,
                    averageStayMinutes,
                    visitsLast7Days
                };
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public Task<ResponseDTO> Update(Guid id, PlaceDTO objectDTO)
        {
            throw new NotImplementedException();
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