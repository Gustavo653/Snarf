using FloralImage.DTO;
using FloralImage.Infrastructure.Service;
using Microsoft.AspNetCore.Mvc;

namespace FloralImage.API.Controllers
{
    public class InvoiceConfigurationController(IInvoiceConfigurationService invoiceConfigurationService) : BaseController
    {
        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateInvoiceConfiguration([FromRoute] Guid id, [FromBody] InvoiceConfigurationDTO invoiceConfigurationDTO)
        {
            var invoiceConfiguration = await invoiceConfigurationService.Update(id, invoiceConfigurationDTO);
            return StatusCode(invoiceConfiguration.Code, invoiceConfiguration);
        }

        [HttpGet("")]
        public async Task<IActionResult> GetInvoiceConfigurations()
        {
            var invoiceConfiguration = await invoiceConfigurationService.GetList();
            return StatusCode(invoiceConfiguration.Code, invoiceConfiguration);
        }
    }
}