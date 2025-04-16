using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PlaceRepository(SnarfContext context) : BaseRepository<Place, SnarfContext>(context), IPlaceRepository;
}
