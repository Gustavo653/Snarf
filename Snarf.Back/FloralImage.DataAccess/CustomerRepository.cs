using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class CustomerRepository(FloralImageContext context) : BaseRepository<Customer, FloralImageContext>(context), ICustomerRepository
    {
    }
}
