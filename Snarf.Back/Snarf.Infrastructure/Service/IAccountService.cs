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
        Task<ResponseDTO> GetCurrent(Guid id);
        Task<ResponseDTO> UpdateUser(Guid id, UserDTO userDTO);
        Task<ResponseDTO> RemoveUser(Guid id);
    }
}