using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class FavoriteChatRepository(SnarfContext context) : BaseRepository<FavoriteChat, SnarfContext>(context), IFavoriteChatRepository;
}
