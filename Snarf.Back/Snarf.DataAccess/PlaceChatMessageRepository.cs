using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PlaceChatMessageRepository(SnarfContext context) : BaseRepository<PlaceChatMessage, SnarfContext>(context), IPlaceChatMessageRepository;
}
