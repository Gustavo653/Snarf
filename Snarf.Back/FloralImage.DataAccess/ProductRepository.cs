using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class ProductRepository(FloralImageContext context) : BaseRepository<Product, FloralImageContext>(context), IProductRepository
    {
    }
}
