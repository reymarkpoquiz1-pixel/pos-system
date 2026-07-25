import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('store_settings')
export class StoreSetting {
  @PrimaryColumn({ default: 1 })
  id: number;

  @Column({ name: 'store_name' })
  storeName: string;

  @Column({ nullable: true })
  address: string;

  @Column({ nullable: true })
  phone: string;

  @Column({ nullable: true })
  email: string;

  @Column({
    name: 'tax_rate',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  taxRate: number;

  @Column({ name: 'logo_url', nullable: true })
  logoUrl: string;
}
