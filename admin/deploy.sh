bun run build

cd dist && 7z a admin.7z *

scp admin.7z xin-im-prod-0:/home/ubuntu
