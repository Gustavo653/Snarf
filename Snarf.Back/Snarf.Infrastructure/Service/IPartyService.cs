using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Base;

namespace Snarf.Infrastructure.Service
{
    public interface IPartyService : IBaseService<PartyDTO>
    {
        Task<ResponseDTO> InviteUsers(Guid id, List<string> userIds, string whoIsCallingId);
        Task<ResponseDTO> GetAll(Guid userId);
        Task<ResponseDTO> RequestParticipation(Guid partyId, string userId);
        Task<ResponseDTO> ConfirmUser(Guid partyId, string whoIsCallingId, string targetUserId);
        Task<ResponseDTO> DeclineUser(Guid partyId, string whoIsCallingId, string targetUserId);
        Task<ResponseDTO> GetAllParticipants(Guid id, Guid userId);
        Task<ResponseDTO> GetById(Guid id, Guid userId);
        Task<ResponseDTO> Delete(Guid id, Guid userId);
    }
}
