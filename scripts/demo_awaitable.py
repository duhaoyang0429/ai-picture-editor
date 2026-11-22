import asyncio
import inspect


async def hello():
    return "hi"


async def gen():
    yield 1


# ① 类型判断：函数 vs 协程对象 vs 异步生成器
print(hello)
print(hello())
print(inspect.isawaitable(hello))
print(inspect.isawaitable(hello()))
print(inspect.isawaitable(gen()))


# ② 同一个协程对象只能 await 一次
async def twice():
    c = hello()
    await c
    try:
        await c
    except RuntimeError as exc:
        print("第二次 await：", exc)


# ③ Task 可以多次 await
async def task_twice():
    t = asyncio.create_task(hello())
    print(await t)
    print(await t)


# ④ gather 一次等多个
async def gather_demo():
    result = await asyncio.gather(hello(), hello())
    print(result)


asyncio.run(twice())
asyncio.run(task_twice())
asyncio.run(gather_demo())
