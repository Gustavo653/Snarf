using FloralImage.Domain.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class UserRepository(FloralImageContext context) : BaseRepository<User, FloralImageContext>(context), IUserRepository;
}
