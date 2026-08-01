import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';
import * as fs from 'fs';

const execPromise = promisify(exec);

@Injectable()
export class BackupService {
  private readonly logger = new Logger(BackupService.name);

  constructor(private configService: ConfigService) {}

  async createBackup() {
    const dbName = this.configService.get<string>('DB_DATABASE');
    const dbUser = this.configService.get<string>('DB_USERNAME');
    const dbPass = this.configService.get<string>('DB_PASSWORD');
    const dbHost = this.configService.get<string>('DB_HOST');
    const dbPort = this.configService.get<string>('DB_PORT');

    const backupDir = path.join(process.cwd(), 'backups');
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir);
    }

    const filename = `pos_backup_${new Date().toISOString().replace(/[:.]/g, '-')}.sql`;
    const filePath = path.join(backupDir, filename);

    // PostgreSQL pg_dump command
    // Note: This requires pg_dump to be installed and PGPASSWORD set or .pgpass configured
    const command = `pg_dump -h ${dbHost} -p ${dbPort} -U ${dbUser} -d ${dbName} -f "${filePath}"`;

    try {
      // Setting PGPASSWORD environment variable for pg_dump
      await execPromise(command, {
        env: { ...process.env, PGPASSWORD: dbPass },
      });
      this.logger.log(`Backup created successfully: ${filename}`);
      return {
        success: true,
        message: 'Backup created successfully',
        file: filename,
      };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.logger.error(`Backup failed: ${errorMessage}`);
      return { success: false, message: 'Backup failed', error: errorMessage };
    }
  }
}
