import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity('payment_gateways')
export class PaymentGateway {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'gateway_name' })
  gatewayName: string;

  @Column({ name: 'is_active', default: true })
  isActive: boolean;
}
