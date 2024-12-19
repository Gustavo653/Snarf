using FloralImage.DTO.Base;

namespace FloralImage.Infrastructure.Service
{
    public interface ICityService
    {
        Task<ResponseDTO> GetCitiesByState(Guid stateId);
        Task<ResponseDTO> SyncCities();
    }
}