using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Persistence;

namespace Snarf.DataAccess
{
    public class PartyRepository(SnarfContext context) : BaseRepository<Party, SnarfContext>(context), IPartyRepository;
}
