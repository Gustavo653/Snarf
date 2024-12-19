using FloralImage.Domain.Entities;
using FloralImage.DTO;
using FloralImage.DTO.Base;
using FloralImage.Infrastructure.Repository;
using FloralImage.Infrastructure.Service;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace FloralImage.Service
{
    public class InvoiceConfigurationService(IInvoiceConfigurationRepository invoiceConfigurationRepository, IStateRepository stateRepository, ICityRepository cityRepository) : IInvoiceConfigurationService
    {
        public async Task<ResponseDTO> Update(Guid id, InvoiceConfigurationDTO invoiceConfigurationDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var state = await stateRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == invoiceConfigurationDTO.StateId);
                if (state == null)
                {
                    responseDTO.SetBadInput($"O estado {id} não existe!");
                    return responseDTO;
                }

                var city = await cityRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == invoiceConfigurationDTO.CityId);
                if (city == null)
                {
                    responseDTO.SetBadInput($"A cidade {id} não existe!");
                    return responseDTO;
                }

                var invoiceConfiguration = await invoiceConfigurationRepository.GetTrackedEntities().FirstOrDefaultAsync(c => c.Id == id);
                if (invoiceConfiguration == null)
                {
                    invoiceConfiguration = new InvoiceConfiguration()
                    {
                        NextNumber = invoiceConfigurationDTO.NextNumber,
                        Document = invoiceConfigurationDTO.Document,
                        CompanyName = invoiceConfigurationDTO.CompanyName,
                        MunicipalRegistration = invoiceConfigurationDTO.MunicipalRegistration,
                        Address = invoiceConfigurationDTO.Address,
                        PostalCode = invoiceConfigurationDTO.PostalCode,
                        City = city,
                        State = state,
                        Email = invoiceConfigurationDTO.Email,
                    };
                    await invoiceConfigurationRepository.InsertAsync(invoiceConfiguration);
                }
                else
                {
                    invoiceConfiguration.NextNumber = invoiceConfigurationDTO.NextNumber;
                    invoiceConfiguration.Document = invoiceConfigurationDTO.Document;
                    invoiceConfiguration.CompanyName = invoiceConfigurationDTO.CompanyName;
                    invoiceConfiguration.MunicipalRegistration = invoiceConfigurationDTO.MunicipalRegistration;
                    invoiceConfiguration.Address = invoiceConfigurationDTO.Address;
                    invoiceConfiguration.PostalCode = invoiceConfigurationDTO.PostalCode;
                    invoiceConfiguration.State = state;
                    invoiceConfiguration.City = city;
                    invoiceConfiguration.Email = invoiceConfigurationDTO.Email;
                    invoiceConfiguration.SetUpdatedAt();
                }

                await invoiceConfigurationRepository.SaveChangesAsync();
                Log.Information("Configuração persistida id: {id}", invoiceConfiguration.Id);

                responseDTO.Object = invoiceConfigurationDTO;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> GetList()
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await invoiceConfigurationRepository
                    .GetEntities()
                    .Select(x => new
                    {
                        x.NextNumber,
                        x.Document,
                        x.CompanyName,
                        x.MunicipalRegistration,
                        x.Address,
                        x.PostalCode,
                        cityId = x.City.Id,
                        stateId = x.State.Id,
                        x.Email,
                        x.Id
                    }).FirstOrDefaultAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public Task<ResponseDTO> Create(InvoiceConfigurationDTO fuelDTO)
        {
            throw new NotImplementedException();
        }

        public Task<ResponseDTO> Remove(Guid id)
        {
            throw new NotImplementedException();
        }
    }
}
