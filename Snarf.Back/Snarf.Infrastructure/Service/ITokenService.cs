using Snarf.Domain.Base;

namespace Snarf.Infrastructure.Service
{
    public interface ITokenService
    {
        Task<string> CreateToken(User userDTO);
    }
}