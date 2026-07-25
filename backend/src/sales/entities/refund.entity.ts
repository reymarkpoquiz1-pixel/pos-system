import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, ManyToOne, JoinColumn } from 'typeorm';
import { Sale } from './sale.entity';

export enum RefundStatus {
  PENDING = 'Pending',
  APPROVED = 'Approved',
  REJECTED = 'Rejected',
}

@Entity('refunds')
export class Refund {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'sale_id' })
  saleId!: number;

  @ManyToOne(() => Sale)
  @JoinColumn({ name: 'sale_id' })
  sale!: Sale;

  @Column({ type: 'text', nullable: true })
  reason!: string;

  @Column({ name: 'refund_amount', type: 'decimal', precision: 10, scale: 2 })
  refundAmount!: number;

  @Column({
    type: 'enum',
    enum: RefundStatus,
    default: RefundStatus.PENDING,
  })
  status!: RefundStatus;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}
