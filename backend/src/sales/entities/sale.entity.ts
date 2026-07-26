import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn,
  Index,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';
import { Customer } from '../../customers/entities/customer.entity';
import { Branch } from '../../branches/entities/branch.entity';
import { SaleItem } from './sale-item.entity';

export enum PaymentMethod {
  CASH = 'Cash',
  GCASH = 'Gcash',
  MAYA = 'Maya',
  CARD = 'Card',
}

export enum OrderType {
  WALKIN = 'Walk-in',
  ONLINE = 'Online',
}

export enum PaymentStatus {
  PAID = 'Paid',
  PENDING = 'Pending',
  FAILED = 'Failed',
  REFUNDED = 'Refunded',
}

export enum OrderStatus {
  PENDING = 'Pending',
  PREPARING = 'Preparing',
  SHIPPED = 'Shipped',
  DELIVERED = 'Delivered',
  CANCELLED = 'Cancelled',
}

@Entity('sales')
export class Sale {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'customer_id', nullable: true })
  customerId: number;

  @ManyToOne(() => Customer, (customer) => customer.sales, { nullable: true })
  @JoinColumn({ name: 'customer_id' })
  customer: Customer;

  @Column({ name: 'branch_id', default: 1 })
  branchId: number;

  @ManyToOne(() => Branch, (branch) => branch.sales)
  @JoinColumn({ name: 'branch_id' })
  branch: Branch;

  @Column({ name: 'shift_id', nullable: true })
  shiftId: number;

  @Column({ name: 'total_amount', type: 'decimal', precision: 10, scale: 2 })
  totalAmount: number;

  @Column({ type: 'decimal', precision: 10, scale: 2, default: 0 })
  discount: number;

  @Column({
    name: 'shipping_fee',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  shippingFee: number;

  @Column({ name: 'shipping_address', type: 'text', nullable: true })
  shippingAddress: string;

  @Column({ name: 'final_amount', type: 'decimal', precision: 10, scale: 2 })
  finalAmount: number;

  @Column({ name: 'amount_paid', type: 'decimal', precision: 10, scale: 2 })
  amountPaid: number;

  @Column({ type: 'decimal', precision: 10, scale: 2 })
  change: number;

  @Column({
    name: 'payment_method',
    type: 'enum',
    enum: PaymentMethod,
    default: PaymentMethod.CASH,
  })
  paymentMethod: PaymentMethod;

  @Column({
    name: 'payment_status',
    type: 'enum',
    enum: PaymentStatus,
    default: PaymentStatus.PAID,
  })
  paymentStatus: PaymentStatus;

  @Column({
    name: 'order_status',
    type: 'enum',
    enum: OrderStatus,
    default: OrderStatus.PENDING,
  })
  orderStatus: OrderStatus;

  @Column({
    name: 'order_type',
    type: 'enum',
    enum: OrderType,
  })
  orderType: OrderType;

  @Column({ name: 'payment_reference', length: 100, nullable: true })
  paymentReference: string;

  @CreateDateColumn({ name: 'transaction_date' })
  @Index()
  transactionDate: Date;

  @OneToMany(() => SaleItem, (saleItem) => saleItem.sale, { cascade: true })
  items: SaleItem[];
}
