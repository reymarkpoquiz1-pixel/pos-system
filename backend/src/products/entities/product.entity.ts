import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  Index,
} from 'typeorm';
import { Category } from '../../categories/entities/category.entity';

@Entity('products')
export class Product {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ unique: true, nullable: true })
  barcode: string;

  @Column()
  name: string;

  @Column({ type: 'text', nullable: true })
  description: string;

  @Column({
    name: 'purchase_price',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  purchasePrice: number;

  @Column({
    name: 'selling_price',
    type: 'decimal',
    precision: 10,
    scale: 2,
    default: 0,
  })
  sellingPrice: number;

  @Column({ name: 'stock_quantity', type: 'integer', default: 0 })
  stockQuantity: number;

  @Column({ name: 'reorder_level', type: 'integer', default: 20 })
  reorderLevel: number;

  @Column({ name: 'image_url', nullable: true })
  imageUrl: string;

  @Column({ type: 'jsonb', nullable: true })
  tags: any;

  @Column({ type: 'jsonb', nullable: true })
  variants: any;

  @Column({ default: 'Active' })
  @Index()
  status: string;

  @Column({ name: 'category_id', nullable: true })
  @Index()
  categoryId: number;

  @ManyToOne(() => Category, (category) => category.products, {
    onDelete: 'SET NULL',
  })
  @JoinColumn({ name: 'category_id' })
  category: Category;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
