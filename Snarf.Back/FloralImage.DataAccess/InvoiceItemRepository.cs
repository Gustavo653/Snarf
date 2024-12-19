using FloralImage.Domain.Entities;
using FloralImage.Infrastructure.Repository;
using FloralImage.Persistence;

namespace FloralImage.DataAccess
{
    public class InvoiceItemRepository(FloralImageContext context) : BaseRepository<InvoiceItem, FloralImageContext>(context), IInvoiceItemRepository
    {
    }
}
