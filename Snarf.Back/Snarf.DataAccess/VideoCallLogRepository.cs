using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class VideoCallLogRepository(SnarfContext context) : BaseRepository<VideoCallLog, SnarfContext>(context), IVideoCallLogRepository;
}
