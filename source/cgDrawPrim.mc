
// 15ms for : for (var i = 0; i < 57; i++) { drawCircle1((i) + 10, (i) + 10, 10,dc); }
// quality: **** (perfect)

    function drawCircle1 (x, y, r, dc)
    {
        var r2 = r * r;
        var pcx= (Math.sqrt(r2 - r2) + 0.5);
        for (var cy = -r; cy <= r; cy++)
        {
            var cx = (Math.sqrt(r2 - cy * cy) + 0.5);
            var cyy = cy + y;

            if ((cx - pcx) > 1)
            {
                dc.drawLine(x + pcx, cyy, x + cx, cyy);
                dc.drawLine(x - cx, cyy, x - pcx, cyy);
            }
            else if ((pcx - cx) > 1)
            { 
                dc.drawLine(x + cx, cyy, x + pcx, cyy);
                dc.drawLine(x - pcx, cyy, x - cx, cyy);
            }
            else
            {
                dc.drawPoint(x + cx, cyy);
                dc.drawPoint(x - cx, cyy);    
            }
            
            pcx = cx;
        }
    }

    // 15ms for : for (var i = 0; i < 91; i++) { drawCircle2((i) + 10, (i) + 10, 10,dc); }
    // quality: *** (almost perfect)

    function drawCircle2(x, y, r, dc)
    {
        var x1 = ((r*0.707010678) + 0.5).toNumber();
    
        dc.drawPoint(x+r,y);
        dc.drawPoint(x-r,y);
        dc.drawPoint(x,y+r);
        dc.drawPoint(x,y-r);
        dc.drawPoint(x+x1,y+x1);
        dc.drawPoint(x+x1,y-x1);
        dc.drawPoint(x-x1,y+x1);
        dc.drawPoint(x-x1,y-x1);
        
        var pos_y = -r;
        var tx = 0;
        var ty = 4 * r;
        var a = 0;
        var b = 2 * ty + 9;
        for (var pos_x = 1; pos_x < x1; pos_x++)
        {
            a += 8;
            tx += a;

            if (tx > ty)
            {
                pos_y++;
                b -= 8;
                ty += b;
            }
        
            dc.drawPoint(x+pos_x,y+pos_y);
            dc.drawPoint(x-pos_x,y+pos_y);
            
            dc.drawPoint(x+pos_x,y-pos_y);
            dc.drawPoint(x-pos_x,y-pos_y);
            
            dc.drawPoint(x+pos_y,y+pos_x);
            dc.drawPoint(x-pos_y,y+pos_x);
            
            dc.drawPoint(x+pos_y,y-pos_x);
            dc.drawPoint(x-pos_y,y-pos_x);
        }
    } 

// 15ms for : for (var i = 0; i < 85; i++) { drawCircle((i) + 10, (i) + 10, 10,dc); }
// quality: **** (perfect)

    function drawCircle0 (xc, yc, r, dc)
    {
        dc.drawPoint(xc-r, yc);
        dc.drawPoint(xc+r, yc);
        dc.drawPoint(xc, yc-r);
        dc.drawPoint(xc, yc+r);

        var x = r;
        var y = 0;      //local coords     
        var cd2= 0;    //current distance squared - radius squared
        while (x > y)    //only formulate 1/8 of circle
        {
            --x;
            ++y;
            cd2-= (x - y);
            if (cd2 < 0) { x++; cd2 += x;  }

            dc.drawPoint(xc-x, yc-y);//upper left left
            dc.drawPoint(xc-y, yc-x);//upper upper left
            dc.drawPoint(xc+y, yc-x);//upper upper right
            dc.drawPoint(xc+x, yc-y);//upper right right
            dc.drawPoint(xc-x, yc+y);//lower left left
            dc.drawPoint(xc-y, yc+x);//lower lower left
            dc.drawPoint(xc+y, yc+x);//lower lower right
            dc.drawPoint(xc+x, yc+y);//lower right right
        } 
    }

//        for (var i = 0; i < 87; i++) { drawCircle4((i) + 10, (i) + 10, 10,dc); }
// quality: ** (not perfect)

    function drawCircle4(xc, yc, R, dc)
    {
        var d=5-4*R;
        var dA = 12;
        var dB = 20 - 8 * R;
        var x = 0;
        var y = R;
        while (x < y)
        {
            dc.drawPoint(xc-x, yc-y);//upper left left
            dc.drawPoint(xc-y, yc-x);//upper upper left
            dc.drawPoint(xc+y, yc-x);//upper upper right
            dc.drawPoint(xc+x, yc-y);//upper right right
            dc.drawPoint(xc-x, yc+y);//lower left left
            dc.drawPoint(xc-y, yc+x);//lower lower left
            dc.drawPoint(xc+y, yc+x);//lower lower right
            dc.drawPoint(xc+x, yc+y);//lower right right
            if (d < 0)
            {
                d = d + dA;
                dB = dB + 8;            
            }
            else
            {
                y--;
                d = d + dB;
                dB = dB + 16;                
            }
            x++;
            dA = dA + 8;            
        }
    }

    function drawFilledCircle(x, y, r, dc)
    {
        var r2 = r * r;
        for (var cy = -r; cy <= r; cy++)
        {
            var cx = (Math.sqrt(r2 - cy * cy) + 0.5);
            var cyy = cy + y;

            dc.drawLine(x - cx, cyy, x + cx, cyy);
        }
    }
 
/* doesn't work 
    function drawCircle3 (x, y, radius, dc)
    {    
        var IG = (radius<<1) - 3;
        var IDGR = -6;
        var IDGD = (radius<<2) - 10;
        var w=212;
        var h=212;
        
        var y1check=y+radius;
        var y2check=y-radius;
        var y3check=y;
        var y4check=y;
        
        var IX = 0;
        var IY = radius;
        
        var IX1 = x;
        var IX2 = x;
        var IX3 = x+radius;
        var IX4 = x-radius;
        
        var IY1 = y1check*w;
        var IY2 = y2check*w;
        var IY3 = y3check*w;
        var IY4 = IY3;
        
        if (IX4 >= 0 && IX3 < w && y2check >= 0 && y1check < h)
        {
            while (IY > IX)
            {
                dc.drawPoint(IX1, IY1);
                dc.drawPoint(IX1, IY2);
                dc.drawPoint(IX2, IY1);
                dc.drawPoint(IX2, IY2);
                dc.drawPoint(IX3, IY3);
                dc.drawPoint(IX4, IY4);
                dc.drawPoint(IX3, IY4);
                dc.drawPoint(IX4, IY3);
                if (IG < 0)
                {
                    IG = IG+IDGD;
                    IDGD -= 8;
                    IY--;
                    
                    IY1-=w;
                    IY2+=w;
                    IX3--;
                    IX4++;
                }
                else
                {
                    IG += IDGR;
                    IDGD -=4;
                }
                IDGR -= 4;
                IX++;
                
                IX1++;
                IX2--;
                IY3-=w;
                IY4+=w;
            }
        }
        else
        {
            while (IY > IX)
            {
                if (IX1 >= 0 && IX1 < w)
                {
                    if (y1check >= 0 && y1check < h) { dc.drawPoint(IX1, IY1); }
                    if (y2check >= 0 && y2check < h) { dc.drawPoint(IX1, IY2); }
                }
                if (IX2 >= 0 && IX2 < w)
                {
                    if (y1check >= 0 && y1check < h) { dc.drawPoint(IX2, IY1); }
                    if (y2check >= 0 && y2check < h) { dc.drawPoint(IX2, IY2); }
                }
                if (IX3 >= 0 && IX3 < w)
                {
                    if (y3check >= 0 && y3check < h) { dc.drawPoint(IX3, IY3); }
                    if (y4check >= 0 && y4check < h) { dc.drawPoint(IX3, IY4); }
                }
                if (IX4 >= 0 && IX4 < w)
                {
                    if (y3check >= 0 && y3check < h) { dc.drawPoint(IX4, IY3); }
                    if (y4check >= 0 && y4check < h) { dc.drawPoint(IX4, IY4); }
                }
                
                if (IG < 0)
                {
                    IG = IG+IDGD;
                    IDGD -= 8;
                    IY1-=w;
                    IY2+=w;
                    y1check--;
                    y2check++;
                    IX3--;
                    IX4++;
                    IY--;
                }
                else
                {
                    IG += IDGR;
                    IDGD -=4;
                }
                IDGR -= 4;
                IX++;
                IX1++;
                IX2--;
                IY3-=w;
                IY4+=w;
                y3check--;
                y4check++;
            }
        }
    } 
 */
 