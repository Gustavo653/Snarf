using Snarf.DTO;
using Snarf.DTO.Base;

namespace Snarf.Infrastructure.Service
{
    public interface IPartyService
    {
        Task<ResponseDTO> Create(PartyCreateDTO createDTO);
        Task<ResponseDTO> Update(Guid id, PartyUpdateDTO updateDTO);
        Task<ResponseDTO> InviteUsers(Guid id, AddUsersToPartyDTO request);
        Task<ResponseDTO> GetAll(Guid userId);
        Task<ResponseDTO> ConfirmUser(Guid id, Guid userId);
        Task<ResponseDTO> GetAllParticipants(Guid id, Guid userId);
        Task<ResponseDTO> GetById(Guid id, Guid userId);
    }
}
