using Snarf.Domain.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class UserRepository(SnarfContext context) : BaseRepository<User, SnarfContext>(context), IUserRepository;
}
