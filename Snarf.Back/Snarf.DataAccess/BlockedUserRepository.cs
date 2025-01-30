using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class BlockedUserRepository(SnarfContext context) : BaseRepository<BlockedUser, SnarfContext>(context), IBlockedUserRepository;
}
