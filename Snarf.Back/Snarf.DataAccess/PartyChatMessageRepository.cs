using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PartyChatMessageRepository(SnarfContext context) : BaseRepository<PartyChatMessage, SnarfContext>(context), IPartyChatMessageRepository;
}
