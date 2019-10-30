% what are the distributions of box sizes and shapes if we go totally exhaustive?

% lets assume an n x n image

nr = 30;
nc = 40;

ws = 1:nc;
hs = 1:nr;

coords = zeros(0,4);

for wi = 1:nc
    w = ws(wi);
    c0s = (1:nc-w+1)';
    cfs = c0s+w-1;
    for hi = 1:nr
        h = hs(hi);
        r0s = (1:nr-h+1)';
        rfs = r0s+h-1';
        
        new_coords = [sortrows(repmat([r0s rfs],[numel(c0s),1])) repmat([c0s cfs],[numel(r0s),1])];
        
        coords(end+1:end+size(new_coords,1),:) = new_coords;
        
    end
    
end
    
w_all = (coords(:,4) - coords(:,3) + 1);
h_all = (coords(:,2) - coords(:,1) + 1);

aspect_ratios = w_all ./ h_all;
area_ratios = (w_all .* h_all) / (nr*nc);


rows_remove = aspect_ratios > 5 | aspect_ratios < .2 | area_ratios > .9 | area_ratios < .01;
aspect_ratios(rows_remove,:) = [];
area_ratios(rows_remove,:) = [];



figure;

hn = 20;

subplot_lazy(4,1);
hist(aspect_ratios,hn);
title('aspect ratios');

subplot_lazy(4,2);
hist(area_ratios,hn);
title('area ratios');

subplot_lazy(4,3);
hist(log(aspect_ratios),hn);
title('log aspect ratios');

subplot_lazy(4,4);
hist(log(area_ratios),hn);
title('log area ratios');
    