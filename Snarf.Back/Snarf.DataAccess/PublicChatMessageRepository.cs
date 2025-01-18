using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PublicChatMessageRepository(SnarfContext context) : BaseRepository<PublicChatMessage, SnarfContext>(context), IPublicChatMessageRepository;
}
