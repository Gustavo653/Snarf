using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Base;

namespace Snarf.Infrastructure.Service
{
    public interface IPartyService : IBaseService<PartyDTO>
    {
        Task<ResponseDTO> InviteUsers(Guid id, List<string> userIds);
        Task<ResponseDTO> GetAll(Guid userId);
        Task<ResponseDTO> ConfirmUser(Guid id, Guid userId);
        Task<ResponseDTO> DeclineUser(Guid id, Guid userId);
        Task<ResponseDTO> GetAllParticipants(Guid id, Guid userId);
        Task<ResponseDTO> GetById(Guid id, Guid userId);
        Task<ResponseDTO> Delete(Guid id, Guid userId);
    }
}
