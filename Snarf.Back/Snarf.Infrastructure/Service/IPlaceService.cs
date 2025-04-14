using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Base;

namespace Snarf.Infrastructure.Service
{
    public interface IPlaceService : IBaseService<PlaceDTO>
    {
        Task<ResponseDTO> Update(Guid id, PlaceDTO updateDTO, Guid userId);
        Task<ResponseDTO> Delete(Guid id, Guid userId);
        Task<ResponseDTO> GetById(Guid id);
        Task<ResponseDTO> GetVisitorsAndStats(Guid id);
        Task<ResponseDTO> GetAll();
        Task<ResponseDTO> SignalToRemove(Guid id, Guid userId);
    }
}
