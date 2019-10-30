
% estimating p(cx|\neg x) / p(cx|x)

classifier_struct = load('/Users/Max/Dropbox/Projects/situate/saved_models/dogwalkerdogleash, IOU ridge regression, 0.mat');
num_objs = numel(classifier_struct.classes);

%%

%cx_min = 0;
%cx_max = 1;

cx_min = .2;
cx_max = .8;


cx = linspace( cx_min, cx_max, 1000 );
px = .003;

tfs_exp  = nan(num_objs,2);
mu_diffs = nan(num_objs,1);
mu0s     = nan(num_objs,1);
mu1s     = nan(num_objs,1);
mu_mids  = nan(num_objs,1);
aurocs   = nan(num_objs,1);

odds_ratio = nan(num_objs,numel(cx));
p_cx_neg_x = nan(num_objs,numel(cx));
p_cx_x = nan(num_objs,numel(cx));
px_cx = nan(num_objs,numel(cx));

% gather data for each obj type

for oi = 1:num_objs
    
    % get proper probabilities
    
    mu0    = classifier_struct.model_validation_stats{oi}.mu(1);
    sigma0 = classifier_struct.model_validation_stats{oi}.sigma(1);
    p_cx_neg_x(oi,:) = normpdf( cx, mu0, sigma0 );
    
    mu1    = classifier_struct.model_validation_stats{oi}.mu(2);
    sigma1 = classifier_struct.model_validation_stats{oi}.sigma(2);
    p_cx_x(oi,:) = normpdf( cx, mu1, sigma1 );
    
    odds_ratio(oi,:) = p_cx_neg_x(oi,:) ./ p_cx_x(oi,:);
    
    px_cx(oi,:) = (1 + ((1-px)./px) .* odds_ratio(oi,:) ) .^ (-1);
    
    
    % some book keeping
    
    mu_diffs(oi) = (mu1-mu0)/sigma0;
    mu_mids(oi) = mean([mu1,mu0]);
    aurocs(oi) = classifier_struct.model_validation_stats{oi}.AUROC;
    mu0s(oi) = mu0;
    mu1s(oi) = mu1;
    
    
    
%     % estimate the odds ratio with exp dist
%     
%     mse = @(a,b) mean( (a-b).^2 );
%     t0_exp = [.1,.03];
%     tfs_exp(oi,:) = fminsearch( @(t) mse( exppdf(cx-t(1),t(2)), odds_ratio ), t0_exp );
%     
%     odds_ratio_est = exppdf(cx-tfs_exp(oi,1),tfs_exp(oi,2));
%     px_cx_est = (1 + ((1-px)./px) .* odds_ratio_est ) .^ (-1);
%     
%     
    
end



%% estimate px_cx using auroc, mu0, mu1

mse = @(a,b) mean( (a(:)-b(:)).^2 );

tfuncs = { @(t,ascore,mu0,mu1) t(1) + t(2)*(ascore-.5).^2 + t(3)*mu0 + t(4)*(mu1-mu0), ...
           @(t,ascore,mu0,mu1) t(5) + t(6)*(ascore-.5).^2 + t(7)*mu0 + t(8)*(mu1-mu0) };
t0 = [1 1 0 1, .1 0 1 0];

tfs = fminsearch( @(t) mse( ...
    logistic( cx, tfuncs{1}(t,aurocs,mu0s,mu1s), tfuncs{2}(t,aurocs,mu0s,mu1s) ), ...
    px_cx ) + 0*sum(abs(t)), ...
    t0 );

px_cx_est = logistic( cx, tfuncs{1}(tfs,aurocs,mu0s,mu1s), tfuncs{2}(tfs,aurocs,mu0s,mu1s) );

tfuncs{1}(tfs,aurocs,mu0s,mu1s)
tfuncs{2}(tfs,aurocs,mu0s,mu1s)

figure;
subplot(1,2,1);
plot(cx,px_cx);
hold on;
subplot(1,2,2);
plot(cx,px_cx_est);



%% estimate px_cx using just auroc and a bias term

mse = @(a,b) mean( (a(:)-b(:)).^2 );

tfuncs = { @(t,ascore) t(1) + t(2)*(ascore-.5).^2 , ...
           @(t,ascore) t(3) + t(4)*(ascore-.5).^2 };
t0 = [1 1, .1 0];

tfs = fminsearch( @(t) mse( ...
    logistic( cx, tfuncs{1}(t,aurocs), tfuncs{2}(t,aurocs) ), ...
    px_cx ),...
    t0 );

px_cx_est = logistic( cx, tfuncs{1}(tfs,aurocs), tfuncs{2}(tfs,aurocs) );

tfuncs{1}(tfs,aurocs)
tfuncs{2}(tfs,aurocs)

figure;
subplot(1,2,1);
plot(cx,px_cx);
hold on;
subplot(1,2,2);
plot(cx,px_cx_est);


%% estimate px_cx using just auroc and mu0

mse = @(a,b) mean( (a(:)-b(:)).^2 );

tfuncs = { @(t,ascore,mu0) t(1) + t(2)*(ascore-.5).^2 + t(3)*mu0, ...
           @(t,ascore,mu0) t(4) + t(5)*(ascore-.5).^2 + t(6)*mu0 };
t0 = [1 1 .1, .1 .1 .1];

tfs = fminsearch( @(t) mse( ...
    logistic( cx, tfuncs{1}(t,aurocs,mu0s), tfuncs{2}(t,aurocs,mu0s) ), ...
    px_cx ),...
    t0 );

px_cx_est = logistic( cx, tfuncs{1}(tfs,aurocs,mu0s), tfuncs{2}(tfs,aurocs,mu0s) );

tfuncs{1}(tfs,aurocs,mu0s)
tfuncs{2}(tfs,aurocs,mu0s)

figure;
%subplot(1,2,1);
plot(cx,px_cx);
hold on;
%subplot(1,2,2);
plot(cx,px_cx_est);


%% minimize error in log odds ratio

mse = @(a,b) sum( (a(:)-b(:)).^2 );

tfuncs = { @(t,ascore,mu0) t(1) + t(2)*(ascore-.5).^2 + t(3)*mu0, ...
           @(t,ascore,mu0) t(4) + t(5)*(ascore-.5).^2 + t(6)*mu0 };
t0 = [.01 .01 1, .01 .1 .01]; % first three for the offset, next three for the slope

tfs = fminsearch( ...
        @(t) mse( ...
            log( exppdf( cx - tfuncs{1}(t,aurocs,mu0s), tfuncs{2}(t,aurocs,mu0s) ) ), ...
            log( odds_ratio ) ), ...
        t0 );
    
odds_ratio_est = exppdf( cx - tfuncs{1}(tfs,aurocs,mu0s), tfuncs{2}(tfs,aurocs,mu0s) );

tfuncs{1}(tfs,aurocs,mu0s)
tfuncs{2}(tfs,aurocs,mu0s)

figure;

subplot(1,4,1);
plot(cx,log(odds_ratio));
ylim([-100 20])
title('true log odds ratio')

subplot(1,4,2);
plot(cx,log(odds_ratio_est));
ylim([-100 20])
title('estimated log odds ratio')

subplot(1,4,3);
plot(cx,px_cx);
title('true p(x|cx)');

subplot(1,4,4);
plot(cx, (1 + odds_ratio_est .* (1-px)./px).^(-1) ); 
title('estimated p(x|cx)');




%% minimize error in log odds ratio, model as polynomial

mse = @(a,b) sum( (a(:)-b(:)).^2 );
  
tfuncs = { @(t,ascore,mu0) t(1) + t(2) * 2*(ascore-.5), ...
          @(t,ascore,mu0) t(3) + 0*t(4)*mu0, ...
          @(t,ascore,mu0) t(5) + 0*t(6)*mu0 };

% tfuncs = { @(t,ascore,mu0) t(1) + t(2)*2*(ascore-.5), ...
%           @(t,ascore,mu0) t(3) + t(4)*2*(ascore-.5), ...
%           @(t,ascore,mu0) t(5) + t(6)*2*(ascore-.5) };


% log odds modeling
log_odds_ratio_est_f = @( x, a, k, h ) a .* ( x - h ).^2 + k;
if exist('tfs','var') && ~isempty(tfs) && ~any(isnan(tfs(:)))
    t0 = tfs;
else
    t0 = [ 102.8034 -152.8188    2.4943    0.0000   -0.2169    3.5428];
end

log_odds_ratio_est_f_linear = @( x, a, k, h ) a .* ( x - h ) + k;
%log_odds_ratio_est_f = @( x, a, k, h ) a .* normpdf( x - h ) + k;

[tfs,fval] = fminsearch( ...
        @(t) mse( ...
            log_odds_ratio_est_f( cx, tfuncs{1}(t,aurocs,mu0s), tfuncs{2}(t,aurocs,mu0s), tfuncs{3}(t,aurocs,mu0s) ), ...
            log( odds_ratio ) ) + ...
        + 100 * mean(abs(t)), ... % regularizer
        t0 );
display(fval);



t0 = [37  -82    4    0   0   0];


[tfs_linear,fval] = fminsearch( ...
        @(t) mse( ...
            log_odds_ratio_est_f_linear( cx, tfuncs{1}(t,aurocs,mu0s), tfuncs{2}(t,aurocs,mu0s), tfuncs{3}(t,aurocs,mu0s) ), ...
            log( odds_ratio ) ) + ...
        + 500 * mean(abs(t)), ... % regularizer
        t0 );
display(fval);

display( tfuncs{1}(tfs,aurocs,mu0s) );
display( tfuncs{2}(tfs,aurocs,mu0s) );
display( tfuncs{3}(tfs,aurocs,mu0s) );


odds_ratio_est = exp( log_odds_ratio_est_f( cx, tfuncs{1}(tfs,aurocs,mu0s), tfuncs{2}(tfs,aurocs,mu0s), tfuncs{3}(tfs,aurocs,mu0s) ) );

odds_ratio_est_linear = exp( log_odds_ratio_est_f_linear( cx, tfuncs{1}(tfs_linear,aurocs,mu0s), tfuncs{2}(tfs_linear,aurocs,mu0s), tfuncs{3}(tfs_linear,aurocs,mu0s) ) );






figure('color','white');

subplot2(2,3,1,1);
plot(cx,log(odds_ratio));
ylim([-40 10])
title('estimated with per-class $\mu,\sigma$','Interpreter','latex');
legend(classifier_struct.classes)
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')

subplot2(2,3,1,2);
plot(cx,log(odds_ratio_est));
ylim([-40 10])
title('polynomial estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')


subplot2(2,3,1,3);
plot(cx,log(odds_ratio_est_linear));
ylim([-40 10])
title('linear estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')



subplot2(2,3,2,1);
plot(cx, (1 + odds_ratio .* (1-px)./px).^(-1) );
title('estimated with per-class $\mu,\sigma$','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')

subplot2(2,3,2,2);
plot(cx, (1 + odds_ratio_est .* (1-px)./px).^(-1) ); 
title('polynomial estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')

subplot2(2,3,2,3);
plot(cx, (1 + odds_ratio_est_linear .* (1-px)./px).^(-1) ); 
title('linear estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')


%% dumping all mu0


mse = @(a,b) sum( (a(:)-b(:)).^2 );
  
tfuncs = { @(t,ascore) t(1) + t(2) * 2*(ascore-.5), ...
          @(t,ascore) t(3), ... 
          @(t,ascore) t(4) };


% log odds modeling

log_odds_ratio_est_f = @( x, a, k, h ) a .* ( x - h ).^2 + k;
t0 = [ 102.8034 -152.8188    2.4943       -0.2169];

[tfs,fval] = fminsearch( ...
        @(t) mse( ...
            log_odds_ratio_est_f( cx, tfuncs{1}(t,aurocs), tfuncs{2}(t,aurocs), tfuncs{3}(t,aurocs) ), ...
            log( odds_ratio ) ) + ...
        + 200 * mean(abs(t)), ... % regularizer
        t0 );
display(fval);

odds_ratio_est = exp( log_odds_ratio_est_f( cx, tfuncs{1}(tfs,aurocs), tfuncs{2}(tfs,aurocs), tfuncs{3}(tfs,aurocs) ) );



log_odds_ratio_est_f_linear = @( x, a, k, h ) a .* ( x - h ) + k;
t0 = [37  -82    4     0 ];

[tfs_linear,fval] = fminsearch( ...
        @(t) mse( ...
            log_odds_ratio_est_f_linear( cx, tfuncs{1}(t,aurocs), tfuncs{2}(t,aurocs), tfuncs{3}(t,aurocs) ), ...
            log( odds_ratio ) ) + ...
        + 200 * mean(abs(t)), ... % regularizer
        t0 );
display(fval);

odds_ratio_est_linear = exp( log_odds_ratio_est_f_linear( cx, tfuncs{1}(tfs_linear,aurocs), tfuncs{2}(tfs_linear,aurocs), tfuncs{3}(tfs_linear,aurocs) ) );



odds_ratio_est_linear_f = @(cx,tfs,aurocs) exp( (tfs(1) + tfs(2).*2*(aurocs-.5))  .*  ( cx - tfs(4) ) + tfs(3) );

odds_ratio_est_linear = odds_ratio_est_linear_f(cx,tfs_linear,aurocs);




log_odds_ratio_est_f_const = @(x, a ) a * ones(size(x));
t0_const = [0 0];

[tfs_const,fval] = fminsearch( ...
        @(t) mse( ...
            log_odds_ratio_est_f_const( cx, tfuncs{1}(t,aurocs) ), ...
            log( odds_ratio ) ) + ...
        + 10 * mean(abs(t)), ... % regularizer
        t0_const );

odds_ratio_est_const = exp( log_odds_ratio_est_f_const( cx, tfuncs{1}(tfs_linear,aurocs) ) );







figure('color','white');

subplot2(2,3,1,1);
plot(cx,log(odds_ratio));
ylim([-40 10])
title('estimated with per-class $\mu,\sigma$','Interpreter','latex');
legend(classifier_struct.classes)
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')

subplot2(2,3,1,2);
plot(cx,log(odds_ratio_est));
ylim([-40 10])
title('polynomial estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')


subplot2(2,3,1,3);
plot(cx,log(odds_ratio_est_linear));
ylim([-40 10])
title('linear estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('log$\frac{p(c_x|\neg x)}{p(c_x|x)}$','Interpreter','latex')



subplot2(2,3,2,1);
plot(cx, (1 + odds_ratio .* (1-px)./px).^(-1) );
title('estimated with per-class $\mu,\sigma$','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')

subplot2(2,3,2,2);
plot(cx, (1 + odds_ratio_est .* (1-px)./px).^(-1) ); 
title('polynomial estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')

subplot2(2,3,2,3);
plot(cx, (1 + odds_ratio_est_linear .* (1-px)./px).^(-1) ); 
title('linear estimate with AUROC','Interpreter','latex');
xlabel('$c_x$','Interpreter','latex')
ylabel('$p(x|c_x)$','Interpreter','latex')




odds_model = [];
odds_model.tfuncs = tfuncs;
odds_model.tfs_poly = tfs;
odds_model.tfs_linear = tfs_linear;
odds_model.est_func_poly = log_odds_ratio_est_f;
odds_model.est_func_linear = log_odds_ratio_est_f_linear;
odds_model.odds_ratio_est_linear_f = odds_ratio_est_linear_f;

















