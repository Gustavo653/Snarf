using FloralImage.DTO;
using FloralImage.Infrastructure.Service;
using FloralImage.Utils;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.OutputCaching;
using System.Text;

namespace FloralImage.API.Controllers
{
    public class InvoiceController(IInvoiceService invoiceService) : BaseController
    {
        [HttpGet("{startDate:datetime}/{endDate:datetime}")]
        public async Task<IActionResult> GetInvoices([FromRoute] DateTime startDate, [FromRoute] DateTime endDate)
        {
            var invoice = await invoiceService.GetInvoices(startDate, endDate);
            return StatusCode(invoice.Code, invoice);
        }

        [HttpGet("{id:guid}")]
        public async Task<IActionResult> GetInvoiceById([FromRoute] Guid id)
        {
            var invoice = await invoiceService.GetInvoiceById(id);
            return StatusCode(invoice.Code, invoice);
        }

        [HttpPost("{id:guid}")]
        public async Task<IActionResult> SaveInvoice([FromRoute] Guid? id, [FromBody] InvoiceDTO invoiceDTO)
        {
            var invoice = await invoiceService.SaveInvoice(id, invoiceDTO);
            return StatusCode(invoice.Code, invoice);
        }

        [HttpPut("BillInvoice/{id:guid}")]
        public async Task<IActionResult> BillInvoice([FromRoute] Guid id)
        {
            var invoice = await invoiceService.BillInvoice(id);
            return StatusCode(invoice.Code, invoice);
        }

        [HttpPut("CancelInvoice/{id:guid}")]
        public async Task<IActionResult> CancelInvoice([FromRoute] Guid id)
        {
            var invoice = await invoiceService.CancelInvoice(id);
            return StatusCode(invoice.Code, invoice);
        }

        [HttpGet("GeneratePdfByInvoiceId/{id:guid}")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GeneratePdfByInvoiceId([FromRoute] Guid id)
        {
            var bytes = await invoiceService.GeneratePdfByInvoiceId(id);
            return File(bytes, "application/pdf", "invoice.pdf");
        }

        [HttpGet("GenerateZipPdfByDate/{startDate:datetime}/{endDate:datetime}")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GenerateZipPdfByDate([FromRoute] DateTime startDate, [FromRoute] DateTime endDate)
        {
            var zipBytes = await invoiceService.GenerateZipPdfByDate(startDate, endDate);
            return File(zipBytes, "application/zip", "invoices.zip");
        }

        [HttpGet("GenerateReportByDate/{startDate:datetime}/{endDate:datetime}")]
        [OutputCache(PolicyName = Consts.CacheName, Duration = Consts.CacheTimeout, VaryByHeaderNames = ["Authorization"])]
        public async Task<IActionResult> GenerateReportByDate([FromRoute] DateTime startDate, [FromRoute] DateTime endDate)
        {
            var csv = await invoiceService.GenerateReportByDate(startDate, endDate);
            var bytes = Encoding.UTF8.GetBytes(csv);
            return File(bytes, "text/csv", "report.csv");
        }
    }
}