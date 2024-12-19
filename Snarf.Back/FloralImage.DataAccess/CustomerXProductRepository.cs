using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class CustomerXProductRepository(FloralImageContext context) : BaseRepository<CustomerXProduct, FloralImageContext>(context), ICustomerXProductRepository
    {
    }
}
