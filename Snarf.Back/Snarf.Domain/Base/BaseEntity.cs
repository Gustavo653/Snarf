using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Snarf.Domain.Base
{
    public abstract class BaseEntity
    {
        protected BaseEntity()
        {
            SetCreatedAt();
        }

        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public Guid Id { get; set; }
        public DateTime CreatedAt { get; private set; }
        public DateTime UpdatedAt { get; private set; }

        private void SetCreatedAt()
        {
            CreatedAt = DateTime.UtcNow;
            SetUpdatedAt();
        }

        public void SetCreatedAt(DateTime dateTime)
        {
            CreatedAt = dateTime;
        }

        public void SetUpdatedAt()
        {
            UpdatedAt = DateTime.UtcNow;
        }
    }
}
