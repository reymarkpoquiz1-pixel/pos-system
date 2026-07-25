import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

@Entity('api_requests')
@Index(['ipAddress', 'requestTime'])
export class ApiRequest {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: 'ip_address', length: 45 })
  ipAddress!: string;

  @Column({ length: 255 })
  endpoint!: string;

  @Column({ name: 'request_time', type: 'bigint' })
  requestTime!: number;
}
