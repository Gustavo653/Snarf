using Snarf.DTO;
using Snarf.DTO.Base;

namespace Snarf.Infrastructure.Service
{
    public interface IAccountService
    {
        Task<ResponseDTO> Login(UserLoginDTO userLoginDTO);
        Task<ResponseDTO> CreateUser(UserDTO userDTO);
        Task<ResponseDTO> ResetPassword(UserEmailDTO userEmailDTO);
        Task<ResponseDTO> RequestResetPassword(string email);
        Task<ResponseDTO> GetCurrent(Guid id, bool showSensitiveInfo);
        Task<ResponseDTO> UpdateUser(Guid id, UserDTO userDTO);
        Task<ResponseDTO> RemoveUser(Guid id);
        Task<ResponseDTO> BlockUser(Guid blockerUserId, Guid blockedUserId);
        Task<ResponseDTO> UnblockUser(Guid blockerUserId, Guid blockedUserId);
    }
}