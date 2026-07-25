import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum PromoStatus {
  ACTIVE = 'Active',
  EXPIRED = 'Expired',
  DISABLED = 'Disabled',
}

@Entity('promos')
export class Promo {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true })
  code: string;

  @Column({
    name: 'discount_percent',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  discountPercent: number;

  @Column({
    name: 'discount_fixed',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  discountFixed: number;

  @Column({ name: 'expiry_date', type: 'date' })
  expiryDate: Date;

  @Column({
    type: 'enum',
    enum: PromoStatus,
    default: PromoStatus.ACTIVE,
  })
  status: PromoStatus;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
