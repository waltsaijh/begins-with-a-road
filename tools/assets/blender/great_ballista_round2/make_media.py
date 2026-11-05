"""Lossless APNG and keyframe-board assembly using only Python stdlib.

Run after build.py's --render-stills and --render-animation.
PNG decoding here handles the 8-bit RGB/RGBA non-interlaced Blender outputs.
"""
from pathlib import Path
import struct
import zlib
import binascii

HERE=Path(__file__).resolve().parent
RAW=HERE.parents[3]/'.godot/test-results/modeling/great_ballista_round2'
OUT=HERE/'previews'
SIGNATURE=b'\x89PNG\r\n\x1a\n'


def chunks(path):
    data=path.read_bytes()
    assert data[:8]==SIGNATURE
    offset=8
    while offset<len(data):
        size=struct.unpack_from('>I',data,offset)[0]
        kind=data[offset+4:offset+8]
        payload=data[offset+8:offset+8+size]
        assert binascii.crc32(kind+payload)&0xffffffff==struct.unpack_from('>I',data,offset+8+size)[0]
        yield kind,payload
        offset+=size+12


def chunk(kind,payload):
    return struct.pack('>I',len(payload))+kind+payload+struct.pack('>I',binascii.crc32(kind+payload)&0xffffffff)


def apng(files,destination,fps=12):
    first=list(chunks(files[0]))
    ihdr=first[0][1]
    width,height=struct.unpack_from('>II',ihdr)
    sequence=0
    previous=None
    with destination.open('wb') as out:
        out.write(SIGNATURE)
        out.write(chunk(b'IHDR',ihdr))
        for kind,payload in first[1:]:
            if kind==b'IDAT':break
            out.write(chunk(kind,payload))
        out.write(chunk(b'acTL',struct.pack('>II',len(files),0)))
        for index,file in enumerate(files):
            items=list(chunks(file))
            assert items[0][1]==ihdr
            decoded=decode(file)
            channels,rows=decoded[2],decoded[3]
            if previous is None:
                x0,y0,x1,y1=0,0,width,height
            else:
                changed=[y for y in range(height) if rows[y]!=previous[y]]
                if changed:
                    y0,y1=changed[0],changed[-1]+1
                    x0,x1=width,0
                    for y in changed:
                        row,prior=rows[y],previous[y]
                        left=next(i for i,(a,b) in enumerate(zip(row,prior)) if a!=b)//channels
                        right=width-next(i for i,(a,b) in enumerate(zip(reversed(row),reversed(prior))) if a!=b)//channels
                        x0,x1=min(x0,left),max(x1,right)
                else:
                    x0,y0,x1,y1=0,0,1,1
            out.write(chunk(b'fcTL',struct.pack('>IIIIIHHBB',sequence,x1-x0,y1-y0,x0,y0,1,fps,0,0)))
            sequence+=1
            if index==0:
                for kind,payload in items:
                    if kind==b'IDAT':out.write(chunk(b'IDAT',payload))
            else:
                raw=b''.join(b'\0'+row[x0*channels:x1*channels] for row in rows[y0:y1])
                out.write(chunk(b'fdAT',struct.pack('>I',sequence)+zlib.compress(raw,6)))
                sequence+=1
            previous=rows
        out.write(chunk(b'IEND',b''))
    print(f'APNG {destination.name}: {len(files)} frames / {fps} fps / {width}x{height}')


def decode(path):
    items=list(chunks(path))
    width,height,depth,color,compress,filtering,interlace=struct.unpack('>IIBBBBB',items[0][1])
    assert depth==8 and color in (2,6) and interlace==0
    channels=4 if color==6 else 3
    packed=zlib.decompress(b''.join(v for k,v in items if k==b'IDAT'))
    stride=width*channels
    rows=[]
    prev=bytearray(stride)
    offset=0
    for _ in range(height):
        kind=packed[offset]
        row=bytearray(packed[offset+1:offset+stride+1])
        offset+=stride+1
        for i in range(stride):
            a=row[i-channels] if i>=channels else 0
            b=prev[i]
            c=prev[i-channels] if i>=channels else 0
            if kind==1:value=a
            elif kind==2:value=b
            elif kind==3:value=(a+b)//2
            elif kind==4:
                p=a+b-c
                pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
                value=a if pa<=pb and pa<=pc else b if pb<=pc else c
            elif kind==0:value=0
            else:raise ValueError(kind)
            row[i]=(row[i]+value)&255
        rows.append(row)
        prev=row
    return width,height,channels,rows,items


def board():
    files=[OUT/f'key_{frame:02d}.png' for frame in (1,26,32,47,59,72)]
    images=[decode(p) for p in files]
    w,h,c=images[0][:3]
    assert all(v[:3]==(w,h,c) for v in images)
    raw=bytearray()
    for row in range(2):
        for y in range(h):
            raw.append(0)
            for col in range(3):raw.extend(images[row*3+col][3][y])
    header=struct.pack('>IIBBBBB',w*3,h*2,8,6 if c==4 else 2,0,0,0)
    with (OUT/'attack_keyframes.png').open('wb') as f:
        f.write(SIGNATURE+chunk(b'IHDR',header))
        for kind,payload in images[0][4][1:]:
            if kind==b'IDAT':break
            f.write(chunk(kind,payload))
        f.write(chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))
    print('Keyframe board: 3 x 2, original pixels, no resampling')


if __name__=='__main__':
    board()
    for folder,name in [('close','attack_preview.png'),('game','attack_game_scale.png')]:
        files=sorted((RAW/folder).glob('*.png'))
        assert len(files)==36,(folder,len(files))
        apng(files,OUT/name)
