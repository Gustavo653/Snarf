using FloralImage.DTO;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Base;

namespace FloralImage.Infrastructure.Service
{
    public interface ICustomerService : IBaseService<CustomerDTO>
    {
        Task<ResponseDTO> GetCustomerById(Guid id);
        Task<ResponseDTO> GetDashboardCustomers();
        Task ImportarClientesCSV();
        Task<string> GenerateReport();
    }
}