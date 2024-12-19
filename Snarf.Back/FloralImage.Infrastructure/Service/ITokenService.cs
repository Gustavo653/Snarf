using FloralImage.Domain.Base;

namespace FloralImage.Infrastructure.Service
{
    public interface ITokenService
    {
        Task<string> CreateToken(User userDTO);
    }
}