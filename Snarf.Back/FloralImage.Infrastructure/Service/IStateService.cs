using FloralImage.DTO.Base;

namespace FloralImage.Infrastructure.Service
{
    public interface IStateService
    {
        Task<ResponseDTO> GetStates();
        Task<ResponseDTO> SyncStates();
    }
}