-- 调用你写的宏，传入两个数字
select
    {{ multiply(10, 50) }} as test_result 