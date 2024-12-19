using FloralImage.Domain.Location;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class StateRepository(FloralImageContext context) : BaseRepository<State, FloralImageContext>(context), IStateRepository
    {
    }
}
