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
        Task<ResponseDTO> GetUserInfo(Guid id, bool showSensitiveInfo);
        Task<ResponseDTO> UpdateUser(Guid id, UserDTO userDTO);
        Task<ResponseDTO> RemoveUser(Guid id);
        Task<ResponseDTO> AddExtraMinutes(AddExtraMinutesDTO addExtraMinutesDTO);
        Task<ResponseDTO> BlockUser(Guid blockerUserId, Guid blockedUserId);
        Task<ResponseDTO> UnblockUser(Guid blockerUserId, Guid blockedUserId);
        Task<ResponseDTO> ReportUserPublicMessage(Guid messageId);
        Task<ResponseDTO> ReportUser(Guid userId);
        Task<ResponseDTO> ChangeEmail(Guid userId, string newEmail, string currentPassword);
        Task<ResponseDTO> ChangePassword(Guid userId, string oldPassword, string newPassword);
        Task<ResponseDTO> GetFirstMessageToday(Guid userid);
    }
}