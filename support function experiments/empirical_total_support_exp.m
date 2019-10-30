




%d = load('/Users/Max/Dropbox/Projects/situate/results/untitled folder/situate_v1_fold_01_2019.07.23.13.19.05.mat');
%d = load('results/dogwalking positives check, v2 w initialization_2019.07.29.11.47.34/situate_v2_updated_support_fold_01_2019.07.29.12.24.00.mat');
%d = load('results/dogwalking positives check, v2 w initialization_2019.07.30.11.06.31/situate_v2_updated_support_fold_01_2019.07.30.11.23.24.mat');
%d = load('/Users/Max/Dropbox/Projects/situate/results/dogwalking oldschool and control/situate_v1_control_fold_01_2019.04.16.12.10.46.mat');
d = load('results/dogwalking positives check, quick recent_2019.08.27.15.39.54/situate_v2_total_sup_regress_iou_fold_01_2019.08.27.16.12.16.mat');

records_iter_image = [d.agent_records{:}];

for imi = 1:size(records_iter_image,2)
    for oi = 1:3
        object_iteration_inds = eq(oi, [records_iter_image(:,imi).interest]);
        object_iteration_support = [records_iter_image(object_iteration_inds,imi).support];
        normalized_obj_iou = [object_iteration_support.GROUND_TRUTH] / max([object_iteration_support.GROUND_TRUTH]);
    end
end

ooi   = [records_iter_image.interest]';
sup_rec   = [records_iter_image.support]';
bx = [sup_rec.sample_densities]';
bx = double(bx);
bx(isnan(bx)) = 0;


if isfield( sup_rec, 'sample_densities_prior')
    bx_prior = [sup_rec.sample_densities_prior]';
else
    bx_prior = bx;
end

iou = [sup_rec.GROUND_TRUTH]';
cx  = [sup_rec.internal]';
ext_support_recorded = [sup_rec.external];
tot_support_recorded = [sup_rec.total];



mdl    = load('/Users/Max/Dropbox/Projects/situate/saved_models/dogwalkerdogleash, IOU ridge regression, 0.mat');
objs   = mdl.classes;
aurocs = mdl.AUROCs;
num_objs = numel(objs);


obj_inds = cell(1,numel(objs));
% p_x = nan(1,numel(objs));
pbx_nx = nan(1,numel(objs));
for oi = 1:numel(objs)
    obj_inds{oi} = eq(ooi,oi);
    p_x(oi) = mean( iou(obj_inds{oi}) > .5 );
    %p_bx(oi) = median( bx(obj_inds{oi}) );
    pbx_nx(oi) = mean( bx(obj_inds{oi}) );
end


%% p(x|bx,yby)

% % bootstrap
% p_x = arrayfun( @(oi) mean(iou(ooi==oi)>.5), 1:num_objs );
% pbx_nx =  arrayfun( @(oi) mean(bx(ooi==oi)), 1:num_objs );

% from training data
mdl_sit = load('/Users/Max/Dropbox/Projects/situate/saved_models/dogwalkerdogleash, normal situation model, 0.mat');

p_x = mdl_sit.p_x;
pbx_nx = mdl_sit.bx;


psi = @(t,oi) log( pbx_nx(oi)' ) + log( 1 - p_x(oi)' ) - log( t ) - log( p_x(oi)' );
p_x_bxyby_func = @(t,oi) 1 ./ ( 1 + exp( psi(t,oi) ) );
p_x_bxyby = p_x_bxyby_func( bx, ooi );

figure; 
for oi = 1:num_objs
    subplot(1,num_objs,oi);
    hist(p_x_bxyby(ooi==oi),20);
    xlabel('p_x_bxyby');
    title(objs{oi});
    xlim([0 1]);
end


%% external support


    ext_sup_exp_cdf = nan(size(bx));
    ext_sup_exp_cdf_params = nan(1,numel(objs));
    for oi = 1:numel(objs)
        ext_sup_exp_cdf_params(oi) = mean(p_x_bxyby(ooi==oi));
        ext_sup_exp_cdf( ooi==oi ) = expcdf( p_x_bxyby(ooi==oi), ext_sup_exp_cdf_params(oi) );
        %ext_sup_exp_cdf( obj_inds{oi} ) = expcdf( bx(obj_inds{oi}), mean(bx(obj_inds{oi})) );
    end

    ext_sup_beta_cdf = nan(size(bx));
    beta_dist_params = nan(numel(objs),2);
    for oi = 1:numel(objs)
        beta_dist_params(oi,:) = betafit(double(p_x_bxyby(obj_inds{oi})));
        ext_sup_beta_cdf( obj_inds{oi} ) = betacdf( p_x_bxyby(obj_inds{oi}), beta_dist_params(oi,1), beta_dist_params(oi,2) );
    end
    




%% get p_x_cx 


figure;
for oi = 1:numel(objs)
    subplot2(4,numel(objs),1,oi);
    hist( cx(obj_inds{oi}), 20 );
    title(objs{oi});
    xlabel('cx dist');
    xlim([-.5 1.5]);
    
    subplot2(4,numel(objs),2,oi);
    hist( cx(ooi==oi & iou < .5 ), 20 );
    xlabel('cx dist iou<.5');
    xlim([-.5 1.5]);
    
    subplot2(4,numel(objs),3,oi);
    hist( cx(ooi==oi & iou > .5 ), 20 );
    xlabel('cx dist iou>.5');
    xlim([-.5 1.5]);
    
    subplot2(4,numel(objs),4,oi);
    [auroc, tpr, fpr] = ROC( cx(ooi==oi), iou(ooi==oi) > .5 );
    plot( fpr, tpr );
    text(.5,.5,num2str(auroc,4));
    xlabel('fpr');ylabel('tpr');
    axis([0 1 0 1]);
end

cx_mu_sig    = [ mean(cx(obj_inds{1})) std(cx(obj_inds{1})); ...
                 mean(cx(obj_inds{2})) std(cx(obj_inds{2})); ...
                 mean(cx(obj_inds{3})) std(cx(obj_inds{3})) ];
cx_mu_sig_x  = [ mean(cx(obj_inds{1} & iou > .5)) std(cx(obj_inds{1} & iou > .5)); ...
                 mean(cx(obj_inds{2} & iou > .5)) std(cx(obj_inds{2} & iou > .5)); ...
                 mean(cx(obj_inds{3} & iou > .5)) std(cx(obj_inds{3} & iou > .5)) ];
cx_mu_sig_nx = [ mean(cx(obj_inds{1} & iou < .5)) std(cx(obj_inds{1} & iou < .5)); ...
                 mean(cx(obj_inds{2} & iou < .5)) std(cx(obj_inds{2} & iou < .5)); ...
                 mean(cx(obj_inds{3} & iou < .5)) std(cx(obj_inds{3} & iou < .5)) ];
p_cx_x = nan( size( cx ) );
p_cx_nx = nan( size(cx));
for oi = 1:numel(objs)
    p_cx_x(obj_inds{oi})  = normpdf( cx(obj_inds{oi}), cx_mu_sig_x(oi,1),  cx_mu_sig_x(oi,2)  );
    p_cx_nx(obj_inds{oi}) = normpdf( cx(obj_inds{oi}), cx_mu_sig_nx(oi,1), cx_mu_sig_nx(oi,2) ); 
end
p_x_cx = (1 +  ((1-p_x(ooi)')./(p_x(ooi)')) .* (p_cx_nx./p_cx_x) ).^(-1);

normed_dist_div = (cx_mu_sig_x(:,1) - cx_mu_sig_nx(:,1))./cx_mu_sig(:,2);


%% estimate p(x|cx) using auroc and px

ascore = nan(size(cx));
pxs = nan(size(cx));
dist_div = nan(size(cx));
for oi = 1:numel(objs)
    ascore(obj_inds{oi}) = 2*(aurocs(oi)-.5);
    pxs(obj_inds{oi}) = p_x(oi);
    dist_div(obj_inds{oi}) = normed_dist_div(oi);
end



ooi = nan(size(cx));
for oi = 1:3
    ooi( obj_inds{oi} ) = oi;
end

data = [cx ascore log((1-pxs)./pxs)];
%data = [cx, ascore,  cx.*ascore];


% b_pxcx =
% 
%   -28.4780
%    12.7181
%    18.0822
%     0.6263


b_0 = rand(size(data,2)+1,1);
%b_0 = b_f;
b_px_cx = fminsearch( @(b) rmse(  glmval( b, data, 'logit'), p_x_cx ), b_0 );
temp =  glmval( b_px_cx, data, 'logit');
p_x_cx_est = temp;




figure;
subplot(1,4,1);
for oi = 1:numel(objs)
    plot(cx(ooi==oi),p_x_cx(ooi==oi),'.'); hold on;
end
axis([-.2 1.2 0 1]);
hold on;
subplot(1,4,2);
for oi = 1:numel(objs)
    plot(cx(ooi==oi),p_x_cx_est(ooi==oi),'.'); hold on;
end
axis([-.2 1.2 0 1]);
subplot(1,4,3);
hist(cx,20);

%% combine p_x_cx, p_x_bx; get some additional options

p_x_cx = p_x_cx_est;


p_x_cxbxyby = p_x_cx .* p_x_bxyby;

log_p_x_cxbxyby = log(p_x_cx) + log(p_x_bxyby);



figure;

for oi = 1:numel(objs)

    ci = ooi == oi;
    
    subplot2(numel(objs),3,oi,1);
    cur_x = p_x_cxbxyby(ci);
    cur_y = iou(ci);
    plot( cur_x, cur_y, '.'); hold on;
    plot( sort(cur_x), local_stat( cur_y(sortorder(cur_x)),1000), 'linewidth',2 );
    axis([0 1 0 1]);
    xlabel('p(x|cx,bx,yby)');
    ylabel({objs{oi},'iou'});
    
    subplot2(numel(objs),3,oi,2);
    cur_x = ext_sup_exp_cdf(ci);
    cur_y = iou(ci);
    plot( cur_x, cur_y, '.'); hold on;
    plot( sort(cur_x), local_stat( cur_y(sortorder(cur_x)),1000), 'linewidth',2 );
    axis([0 1 0 1]);
    xlabel('exp cdf p(x|cx,bx,yby)');
    ylabel('iou');

    subplot2(numel(objs),3,oi,3);
    cur_x = ext_sup_beta_cdf(ci);
    cur_y = iou(ci);
    plot( cur_x, cur_y, '.'); hold on;
    plot( sort(cur_x), local_stat( cur_y(sortorder(cur_x)),1000), 'linewidth',2 );
    axis([0 1 0 1]);
    xlabel('beta cdf p(x|cx,bx,yby)');
    ylabel('iou');
    
end


%% look at internal / external support



%external_support = ext_sup_ratio;
external_support = ext_sup_exp_cdf;
%external_support = ext_sup_beta_cdf;


figure('color','white');
for oi = 1:numel(objs) 
    
    subplot2( numel(objs), 7, oi, 1 ); 
        hist( p_x_cx(obj_inds{oi} ), 20 );
        if oi == 1, title('p(x|cx)'); end
        ylabel(objs{oi});
    subplot2( numel(objs), 7, oi, 2 ); 
        plot( cx(obj_inds{oi}), iou(obj_inds{oi}),'.');
        if oi == 1, title('cx vs iou'); end
        xlim([ min(0,prctile(cx,1)), max(1,prctile(cx,99))]);
        ylim([0 1]);
    subplot2( numel(objs), 7, oi, 3 ); 
        plot( p_x_cx(obj_inds{oi}), iou(obj_inds{oi}),'.');
        if oi == 1, title('p(x|cx) vs iou'); end
        xlim([0 1]);
        ylim([0 1]);
    subplot2( numel(objs), 7, oi, 4 ); 
        hist( p_x_bxyby(obj_inds{oi} ), 20 ); 
        if oi == 1, title('p(x|bx,y,by)'); end
        xlim([0 1]);
    subplot2( numel(objs), 7, oi, 5 ); 
        plot( p_x_bxyby(obj_inds{oi}), iou(obj_inds{oi}),'.'); 
        if oi == 1, title('p(x|bx,y,by) vs iou'); end
        xlim([0 1]);
        ylim([0 1]);
    subplot2( numel(objs), 7, oi, 6 ); 
        hist( external_support(obj_inds{oi} ), 20 ); 
        if oi == 1, title('ext sup'); end
        xlim([0 1]);
    subplot2( numel(objs), 7, oi, 7 ); 
        plot( external_support(obj_inds{oi}), iou(obj_inds{oi}),'.'); 
        if oi == 1, title('ext sup vs iou'); end
        xlim([0 1]);
        
end


%% look at combinations

% just get the total support given mixing params
mix1 = @(int,ext,c) c(1) * int + (1-c(1)) * ext;
mix2 = @(int,ext,c) c(1) * int + c(2) * ext;
mix3 = @(int,ext,c) c(1) * int + c(2) * ext + c(3) * int .* ext;

% get mixing params from a function fo the auroc
cfunc1 = @(t,auroc) t(1) + t(2) * (auroc - t(3) );
cfunc2 = @(t,auroc) [t(1) + t(2) * (auroc - t(3) ), t(4) + t(5) * (auroc - t(6) )];
cfunc3 = @(t,auroc) [t(1) + t(2) * (auroc - t(3) ), t(4) + t(5) * (auroc - t(6) ), t(7) + t(8) * (auroc - t(9) )];

% get the auroc
auroc1 = @( int, ext, auroc, t) mix1( int, ext, cfunc1(t,auroc) );
auroc2 = @( int, ext, auroc, t) mix2( int, ext, cfunc2(t,auroc) );
auroc3 = @( int, ext, auroc, t) mix3( int, ext, cfunc3(t,auroc) );
   

% easy stuff
    total_log_pxcxbxyby = log(p_x_cx) + log(p_x_bxyby);
    total_pxcxbxyby = exp( total_log_pxcxbxyby );
    mix_term_cx_pxbx = cx .* p_x_bxyby;
    total_baseline_sum = mix1( cx, external_support, .5 );
    
    figure('color','white');
    for oi = 1:numel(obj_inds)
        subplot2( numel(obj_inds),4, oi, 1 );
            hist( total_log_pxcxbxyby( obj_inds{oi} ), 20 );
            ylabel(objs{oi});
            if oi == 1, title('log prod px|cx, px|bx'); end
        subplot2( numel(obj_inds),4, oi, 2 );
            hist( total_pxcxbxyby( obj_inds{oi} ), 20 );
            if oi == 1, title('prod px|cx, px|bx');end
        subplot2( numel(obj_inds),4, oi, 3 );
            hist( mix_term_cx_pxbx( obj_inds{oi} ), 20 );
            if oi == 1, title('prod cx ext');end
        subplot2( numel(obj_inds),4, oi, 4 );
            hist( total_baseline_sum( obj_inds{oi} ), 20 );
            if oi == 1, title('sum cx ext');end
    end
    
    figure('color','white');
    for oi = 1:numel(obj_inds)
        subplot2( numel(obj_inds),4, oi, 1 );
            plot( total_log_pxcxbxyby( obj_inds{oi} ), iou(obj_inds{oi}),'.' );
            ylabel(objs{oi});
            xlim([prctile(total_log_pxcxbxyby,2) 0])
            if oi == 1, title('log prod px|cx, px|bx'); end
        subplot2( numel(obj_inds),4, oi, 2 );
            plot( total_pxcxbxyby( obj_inds{oi} ), iou(obj_inds{oi}),'.' );
            if oi == 1, title('prod px|cx, px|bx');end
            xlim([0 1])
        subplot2( numel(obj_inds),4, oi, 3 );
            plot( mix_term_cx_pxbx( obj_inds{oi} ), iou(obj_inds{oi}),'.' );
            xlim([0 1])
            if oi == 1, title('prod cx ext');end
        subplot2( numel(obj_inds),4, oi, 4 );
            plot( total_baseline_sum( obj_inds{oi} ), iou(obj_inds{oi}),'.' );
            xlim([0 1])
            if oi == 1, title('sum cx ext');end
    end
        
    
    
    
source_description_pairs = {...
    cx,                     'intsup';
    external_support,       'extsup dist cdf';
    p_x_cx_est,             'p(x|cx)';
    p_x_bxyby,              'p(x|bx,yby)';
    p_x_cx_est.*p_x_bxyby,  'p(x|cx,bx,yby)';
    cx .* external_support, 'intsup x extsup';
    (2*(aurocs(ooi)-.5))',    'auroc';
    (2*(aurocs(ooi)-.5))'.*cx, 'intsup x auroc';
    (2*(aurocs(ooi)-.5))'.*external_support, 'extsup x auroc' };
    

source_inds_include = [1 2 3 6 7 8 9];

x = [source_description_pairs{source_inds_include,1}];
    
pad = @(x) [ones(size(x,1),1) x];



% lasso regression to iou
[b_lasso_iou, stat] = lasso( [ones(size(x,1),1) x], iou, 'NumLambda',20 );
auroc_lasso = nan(size(b_lasso_iou,2),numel(objs));
for li = 1:size(b_lasso_iou,2)
    for oi = 1:numel(objs)
        ci = obj_inds{oi};
        cur_total_sup = pad(x) * b_lasso_iou(:,li);
        %auroc_lasso(li,oi) = ROC( cur_total_sup(ci), iou(ci)>.5);
    end
    progress(li,size(b_lasso_iou,2));
end
%b_lasso_final = b_lasso(:,5+argmin(temp(6:end)));
b_lasso_iou_final = b_lasso_iou(:,12);
total_sup_lasso_iou = [ones(size(x,1),1) x] * b_lasso_iou_final;
source_description_pairs( source_inds_include(logical(b_lasso_iou_final(2:end))), 2)


% logistic regression to x
[ b_logreg_x, p ] = logregfit( x, iou>.2 );
total_sup_logreg_x = p;
auroc_fit = nan(1,numel(objs));
for oi = 1:numel(objs)
    ci = obj_inds{oi};
    auroc_fit(oi) = ROC( total_sup_logreg_x(ci), iou(ci)>.5);
end

% lasso glm
[b_lasso_logistic,STATS] = lassoglm(pad(x),iou>.2,'binomial');
b_lasso_logistic_final = b_lasso_logistic(:,1);
total_sup_lasso_x = glmval( b_lasso_logistic_final, x, 'logit');
plot(total_sup_lasso_x,iou,'.');



% take a look at whether or not these total sup values are good enough to get into the workspace in
% the first place


exp_cdf_x_regression = nan(size(total_sup_lasso_x));
for oi = 1:numel(objs)
    exp_cdf_x_regression(obj_inds{oi}) = expcdf( total_sup_lasso_x(obj_inds{oi}), mean(total_sup_lasso_x(obj_inds{oi})));
end


total_sup_sources = { ...
    total_sup_lasso_iou, ...
    total_sup_lasso_x };




total_sup_sources_desc = {...
    'linreg iou', ...
    'logreg x' };
%     'baseline', ...
%     'p(x|cx,bx,y,by)', ...
%     'linreg x', ...



error_vals       = nan( numel(total_sup_sources), numel(objs), 3 );
error_val_counts = nan( numel(total_sup_sources), numel(objs), 3 );
rmse_vals = nan( numel(total_sup_sources), numel(objs), 3 );

for tssi = 1:numel(total_sup_sources)
    total_sup = total_sup_sources{tssi};

    figure('color','white','name',total_sup_sources_desc{tssi});
    for oi = 1:numel(objs)

        subplot2(3,numel(objs),1,oi);
        cur_inds = obj_inds{oi};
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' )
        hold on; plot( sort(x_cur), local_stat( y_cur(sortorder(x_cur)), 500 ), 'r','linewidth',2); hold off;
        title(objs{oi});
        xlabel('total sup logreg');
        ylabel('iou');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,1) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,1) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,1) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,1) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,1) ) );
        
        subplot2(3,numel(objs),2,oi);
        cut_off = prctile(bx(obj_inds{oi}),25);
        cur_inds = obj_inds{oi} & bx<cut_off;
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' );
        hold on; plot( sort(x_cur), local_stat( y_cur(sortorder(x_cur)), 500 ), 'r','linewidth',2); hold off;
        xlabel('total sup logreg, bx < 25prctile');
        ylabel('iou');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,2) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,2) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,2) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,2) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,2) ) );
        
        subplot2(3,numel(objs),3,oi);
        cut_off = prctile(bx(obj_inds{oi}),25);
        cur_inds = obj_inds{oi} & bx>cut_off;
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' );
        hold on; plot( sort(x_cur), local_stat( y_cur(sortorder(x_cur)), 500 ), 'r','linewidth',2); hold off;xlabel('total sup lasso, bx > median');
        xlabel('total sup logreg, bx > 25prctile');
        ylabel('iou');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,3) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,3) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,3) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,3) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,3) ) );
        
        

    end
    
end







for tssi = 1:numel(total_sup_sources)
    total_sup = total_sup_sources{tssi};

    figure('color','white','name',total_sup_sources_desc{tssi});
    for oi = 1:numel(objs)

        subplot2(3,numel(objs),1,oi);
        cur_inds = obj_inds{oi};
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' )
        hold on; plot( sort(x_cur), local_stat( double(y_cur(sortorder(x_cur))>.5), 500 ), 'r','linewidth',2); hold off;
        title(objs{oi});
        xlabel('total sup logreg');
        ylabel('p(iou > .5)');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,1) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,1) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,1) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,1) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,1) ) );
        
        subplot2(3,numel(objs),2,oi);
        cut_off = prctile(bx(obj_inds{oi}),25);
        cur_inds = obj_inds{oi} & bx<cut_off;
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' );
        hold on; plot( sort(x_cur), local_stat( double(y_cur(sortorder(x_cur))>.5), 500 ), 'r','linewidth',2); hold off;
        xlabel('total sup logreg, bx < 25prctile');
        ylabel('p(iou > .5)');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,2) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,2) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,2) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,2) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,2) ) );
        
        subplot2(3,numel(objs),3,oi);
        cut_off = prctile(bx(obj_inds{oi}),25);
        cur_inds = obj_inds{oi} & bx>cut_off;
        x_cur = total_sup(cur_inds);
        y_cur = iou(cur_inds);
        plot( x_cur, y_cur, '.' );
        hold on; plot( sort(x_cur), local_stat( double(y_cur(sortorder(x_cur))>.5), 500 ), 'r','linewidth',2); hold off;
        xlabel('total sup logreg, bx > 25prctile');
        ylabel('p(iou > .5)');
        xlim([0,1]); ylim([0,1]);
        rmse_vals(tssi,oi,3) = rmse( x_cur, y_cur );
        error_vals(tssi,oi,3) = sum( abs( x_cur > .5 - y_cur > .5 ) );
        error_val_counts(tssi,oi,3) = mean(x_cur > .5);
        text(0.05,.95,num2str( error_vals(tssi,oi,3) ) );
        text(0.05,.85,num2str( rmse_vals(tssi,oi,3) ) );
        
        

    end
    
end











    