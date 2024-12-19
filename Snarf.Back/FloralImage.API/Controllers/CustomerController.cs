using FloralImage.DTO;
using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OutputCaching;
using System.Text;

namespace FloralImage.API.Controllers
{
    public class CustomerController(ICustomerService customerService) : BaseController
    {
        [HttpPost("")]
        public async Task<IActionResult> CreateCustomer([FromBody] CustomerDTO customerDTO)
        {
            var customer = await customerService.Create(customerDTO);
            return StatusCode(customer.Code, customer);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateCustomer([FromRoute] Guid id, [FromBody] CustomerDTO customerDTO)
        {
            var customer = await customerService.Update(id, customerDTO);
            return StatusCode(customer.Code, customer);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> RemoveCustomer([FromRoute] Guid id)
        {
            var customer = await customerService.Remove(id);
            return StatusCode(customer.Code, customer);
        }

        [HttpGet("")]
        public async Task<IActionResult> GetCustomers()
        {
            var customer = await customerService.GetList();
            return StatusCode(customer.Code, customer);
        }


        [HttpGet("GetDashboardCustomers")]
        public async Task<IActionResult> GetDashboardCustomers()
        {
            var customer = await customerService.GetDashboardCustomers();
            return StatusCode(customer.Code, customer);
        }


        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetCustomerById([FromRoute] Guid id)
        {
            var customer = await customerService.GetCustomerById(id);
            return StatusCode(customer.Code, customer);
        }

        [HttpGet("ImportarClientesCSV")]
        [AllowAnonymous]
        public async Task<IActionResult> ImportarClientesCSV()
        {
            await customerService.ImportarClientesCSV();
            return Ok();
        }

        [HttpGet("GenerateReport")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GenerateReport()
        {
            var csv = await customerService.GenerateReport();
            var bytes = Encoding.UTF8.GetBytes(csv);
            return File(bytes, "text/csv", "report.csv");
        }
    }
}