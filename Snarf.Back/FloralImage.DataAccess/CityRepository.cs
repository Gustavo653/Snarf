using FloralImage.Domain.Location;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class CityRepository(FloralImageContext context) : BaseRepository<City, FloralImageContext>(context), ICityRepository
    {
    }
}
