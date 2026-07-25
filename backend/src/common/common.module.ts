import { Module, Global } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ApiRequest } from './entities/api-request.entity';

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([ApiRequest])],
  exports: [TypeOrmModule],
})
export class CommonModule {}
