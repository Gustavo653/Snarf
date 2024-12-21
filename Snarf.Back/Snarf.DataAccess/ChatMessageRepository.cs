using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class ChatMessageRepository(SnarfContext context) : BaseRepository<ChatMessage, SnarfContext>(context), IChatMessageRepository;
}
