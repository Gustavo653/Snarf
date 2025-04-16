using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PlaceVisitLogRepository(SnarfContext context) : BaseRepository<PlaceVisitLog, SnarfContext>(context), IPlaceVisitLogRepository;
}
