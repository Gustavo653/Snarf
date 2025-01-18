using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PrivateChatMessageRepository(SnarfContext context) : BaseRepository<PrivateChatMessage, SnarfContext>(context), IPrivateChatMessageRepository;
}
