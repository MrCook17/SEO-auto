export class HttpError extends Error {
  constructor(message, status = 0, url = '') {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.url = url;
  }
}

export class UnexpectedRedirectError extends HttpError {
  constructor(url, status, location) {
    super(`Unexpected HTTP ${status} redirect to ${location || '(missing Location header)'}.`, status, url);
    this.name = 'UnexpectedRedirectError';
    this.location = location;
  }
}

export class SiteBlockedError extends HttpError {
  constructor(message, status, url) {
    super(message, status, url);
    this.name = 'SiteBlockedError';
  }
}

export class BlockingResponseGuard {
  constructor(limit) {
    this.limit = limit;
    this.consecutiveBlockingResponses = 0;
  }

  observe(status, url) {
    if (status === 403 || status === 429) {
      this.consecutiveBlockingResponses += 1;
      if (this.consecutiveBlockingResponses >= this.limit) {
        throw new SiteBlockedError(
          `Figured'Art/search service returned ${status} ${this.consecutiveBlockingResponses} consecutive times; stopping without evasion.`,
          status,
          url,
        );
      }
      return;
    }
    this.consecutiveBlockingResponses = 0;
  }
}

function isTransientStatus(status) {
  return status === 408 || status === 425 || status === 429 || status >= 500;
}

async function delay(milliseconds) {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

export async function requestBufferWithRetry({
  url,
  description,
  config,
  logger,
  blockGuard,
  accept = '*/*',
  referer,
}) {
  let lastError;
  for (let attempt = 1; attempt <= config.maximumRetries; attempt += 1) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), config.requestTimeoutMs);
    try {
      const response = await fetch(url, {
        method: 'GET',
        redirect: 'manual',
        signal: controller.signal,
        headers: {
          Accept: accept,
          'User-Agent': config.userAgent,
          ...(referer ? { Referer: referer } : {}),
        },
      });
      blockGuard.observe(response.status, url);
      if (response.status >= 300 && response.status < 400) {
        throw new UnexpectedRedirectError(url, response.status, response.headers.get('location'));
      }
      if (!response.ok) {
        throw new HttpError(`HTTP ${response.status} returned for ${description}.`, response.status, url);
      }
      return {
        buffer: Buffer.from(await response.arrayBuffer()),
        contentType: response.headers.get('content-type') ?? '',
        status: response.status,
        url: response.url,
      };
    } catch (error) {
      if (error instanceof UnexpectedRedirectError || error instanceof SiteBlockedError) {
        throw error;
      }
      lastError = error;
      const status = error instanceof HttpError ? error.status : 0;
      const retryable = status === 0 || isTransientStatus(status);
      if (!retryable || attempt >= config.maximumRetries) break;
      const waitMs = config.retryBaseDelayMs * 2 ** (attempt - 1);
      await logger.log('WARNING', `${description} retry ${attempt}/${config.maximumRetries}`, {
        url,
        error: error.name === 'AbortError' ? 'Request timed out' : error.message,
        waitMs,
      });
      await delay(waitMs);
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new HttpError(
    `${description} failed after at most ${config.maximumRetries} attempts: ${lastError?.message ?? 'Unknown error'}`,
    lastError instanceof HttpError ? lastError.status : 0,
    url,
  );
}

export async function requestTextWithRetry(options) {
  const result = await requestBufferWithRetry(options);
  return { ...result, text: result.buffer.toString('utf8') };
}
